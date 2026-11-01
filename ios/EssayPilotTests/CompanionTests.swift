import XCTest
@testable import EssayPilot

@MainActor final class CompanionTests: XCTestCase {
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    private func day(_ value: Int, hour: Int = 9) -> Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: value, hour: hour))! }
    private func makeDefaults() -> UserDefaults {
        let name = "companion-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!; addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testDailyCareCountsOncePerDayAndAbsenceNeverRemovesGrowth() {
        let defaults = makeDefaults()
        let cat = CompanionModel(owner: "a", defaults: defaults, calendar: calendar, now: day(1))
        cat.recordVisit(now: day(1), reports: 0); cat.recordVisit(now: day(1, hour: 20), reports: 0)
        cat.pat(now: day(1), reports: 0); cat.pat(now: day(1), reports: 0)
        cat.treat(now: day(1), reports: 0); cat.treat(now: day(1), reports: 0)
        XCTAssertEqual(cat.points(reports: 0), 4)
        XCTAssertTrue(cat.line(CompanionContext(name: "团团", stage: .kitten, hour: 9)).contains("吃过"))
        cat.recordVisit(now: day(9), reports: 0)
        XCTAssertEqual(cat.returnedAfterDays, 8)
        XCTAssertEqual(cat.points(reports: 0), 6)
        XCTAssertTrue(CompanionVoice.line(CompanionContext(name: "团团", stage: .visitor, hour: 10, returnedAfterDays: 8)).contains("你回来啦"))
    }

    func testStagesFollowThresholdsAndReportsCelebrateOnce() {
        XCTAssertEqual(CompanionStage.stage(points: 0), .kitten)
        XCTAssertEqual(CompanionStage.stage(points: 11), .kitten)
        XCTAssertEqual(CompanionStage.stage(points: 12), .visitor)
        XCTAssertEqual(CompanionStage.stage(points: 500), .together)
        let cat = CompanionModel(owner: "a", defaults: makeDefaults(), calendar: calendar, now: day(1))
        XCTAssertEqual(cat.pose(resting: false, reports: 0), .sleeping)
        cat.celebrateIfGrown(reports: 8)
        XCTAssertEqual(cat.stage(reports: 8), .guardian)
        XCTAssertTrue(cat.line(CompanionContext(name: "团团", stage: .guardian, hour: 9)).contains("书页守护"))
        cat.clearResponse(); cat.celebrateIfGrown(reports: 8)
        XCTAssertNil(cat.response)
        XCTAssertEqual(cat.progress(reports: 8).remaining, CompanionStage.partner.threshold - 32)
        XCTAssertNil(cat.progress(reports: 100).remaining)
    }

    func testFocusCreditsElapsedMinutesEarlyAndPlannedMinutesWhenSettledLater() {
        let defaults = makeDefaults()
        let cat = CompanionModel(owner: "a", defaults: defaults, calendar: calendar, now: day(1))
        cat.startFocus(minutes: 25, now: day(1))
        XCTAssertEqual(cat.pose(resting: true, reports: 0), .focusing)
        cat.finishFocus(now: day(1).addingTimeInterval(11 * 60 + 30), reports: 0)
        XCTAssertEqual(cat.state.focusMinutes, 11); XCTAssertFalse(cat.focusing)
        cat.startFocus(minutes: 10, now: day(2))
        let reopened = CompanionModel(owner: "a", defaults: defaults, calendar: calendar)
        XCTAssertTrue(reopened.focusing)
        reopened.settleFocus(now: day(2).addingTimeInterval(5 * 60), reports: 0)
        XCTAssertTrue(reopened.focusing)
        reopened.settleFocus(now: day(3), reports: 0)
        XCTAssertEqual(reopened.state.focusMinutes, 21); XCTAssertEqual(reopened.state.focusSessions, 2)
        XCTAssertEqual(reopened.points(reports: 0), 4)
    }

    func testOwnersAreIsolatedRenamingIsCleanAndEraseResets() {
        let defaults = makeDefaults()
        let first = CompanionModel(owner: "first", defaults: defaults, calendar: calendar, now: day(1))
        first.recordVisit(now: day(1), reports: 0); first.rename("  小橘子是一只很长的名字  ")
        XCTAssertEqual(first.state.name, "小橘子是一只很长")
        XCTAssertEqual(CompanionModel(owner: "second", defaults: defaults, calendar: calendar).state.visitDays, 0)
        XCTAssertEqual(CompanionModel(owner: "first", defaults: defaults, calendar: calendar).state.name, "小橘子是一只很长")
        first.rename("   ")
        XCTAssertEqual(first.state.name, CompanionState.defaultName)
        CompanionModel.erase(owner: "first", defaults: defaults)
        XCTAssertEqual(CompanionModel(owner: "first", defaults: defaults, calendar: calendar).state.visitDays, 0)
    }

    func testLegacyNoteIsReadableUntilTheUserDecides() {
        let defaults = makeDefaults()
        defaults.set("  早点休息。 ", forKey: LocalOwnerDefaults.key("writeright.desk-note", owner: "a"))
        XCTAssertEqual(LegacyDeskNote.load(owner: "a", defaults: defaults), "早点休息。")
        XCTAssertNil(LegacyDeskNote.load(owner: "b", defaults: defaults))
        LegacyDeskNote.erase(owner: "a", defaults: defaults)
        XCTAssertNil(LegacyDeskNote.load(owner: "a", defaults: defaults))
    }

    func testVoiceRespondsToDeskStateWithoutGuilt() {
        func line(_ change: (inout CompanionContext) -> Void) -> String {
            var context = CompanionContext(name: "团团", stage: .visitor, hour: 15); change(&context); return CompanionVoice.line(context)
        }
        XCTAssertTrue(line { $0.resting = true }.contains("歇下"))
        XCTAssertTrue(line { $0.hour = 1 }.contains("睡觉"))
        XCTAssertTrue(line { $0.raining = true }.contains("雨"))
        XCTAssertTrue(line { $0.daysToExam = 3 }.contains("还有 3 天"))
        XCTAssertTrue(line { $0.mood = .tired }.contains("歇一会儿"))
        let all = [line { _ in }, line { $0.hour = 8 }, line { $0.hour = 21 }, line { $0.returnedAfterDays = 5 }]
        for text in all { XCTAssertFalse(text.contains("想你") || text.contains("难过") || text.contains("打卡")) }
    }
}
