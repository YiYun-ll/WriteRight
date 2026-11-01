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

    func testTwoDevicesMergeGrowthWithoutLosingEither() async throws {
        let user = UUID(), owner = user.uuidString, cloud = SyncDirectory()
        let phoneDefaults = makeDefaults(), padDefaults = makeDefaults()
        let phone = CompanionModel(owner: owner, defaults: phoneDefaults, calendar: calendar, now: day(1), deviceID: "phone")
        phone.recordVisit(now: day(1), reports: 0); phone.pat(now: day(1), reports: 0)
        phone.startFocus(minutes: 10, now: day(1)); phone.settleFocus(now: day(1, hour: 10), reports: 0)
        XCTAssertTrue(phone.state.needsUpload)
        let pad = CompanionModel(owner: owner, defaults: padDefaults, calendar: calendar, now: day(2), deviceID: "pad")
        pad.recordVisit(now: day(2), reports: 0); pad.treat(now: day(2), reports: 0)
        pad.startFocus(minutes: 25, now: day(2)); pad.settleFocus(now: day(2, hour: 10), reports: 0)
        pad.rename("Mochi", now: day(2))

        try await CompanionSync.sync(userID: user, store: CompanionStore(defaults: phoneDefaults), transport: cloud)
        try await CompanionSync.sync(userID: user, store: CompanionStore(defaults: padDefaults), transport: cloud)
        let learned = try await CompanionSync.sync(userID: user, store: CompanionStore(defaults: phoneDefaults), transport: cloud)
        XCTAssertTrue(learned)

        let onPhone = try XCTUnwrap(CompanionStore(defaults: phoneDefaults).load(owner: owner))
        let onPad = try XCTUnwrap(CompanionStore(defaults: padDefaults).load(owner: owner))
        XCTAssertEqual(onPhone.growth, onPad.growth)
        XCTAssertFalse(onPhone.needsUpload)
        XCTAssertEqual(onPhone.growth.name, "Mochi")
        XCTAssertEqual(onPhone.growth.metAt, day(1))
        XCTAssertEqual(onPhone.growth.visitDays.count, 2)
        XCTAssertEqual(onPhone.growth.totalFocusMinutes, 35)
        phone.reload()
        XCTAssertEqual(phone.state.name, "Mochi")
        XCTAssertEqual(phone.points(reports: 0), 2 * 2 + 1 + 1 + 35 / 5)
        // Syncing again with nothing new changes nothing.
        let again = try await CompanionSync.sync(userID: user, store: CompanionStore(defaults: padDefaults), transport: cloud)
        XCTAssertFalse(again)
    }

    func testCareGivenWhileTheMergeIsInFlightIsKept() async throws {
        let user = UUID(), owner = user.uuidString, defaults = makeDefaults()
        let cat = CompanionModel(owner: owner, defaults: defaults, calendar: calendar, now: day(1), deviceID: "phone")
        cat.recordVisit(now: day(1), reports: 0)
        let third = day(3)
        let transport = MergeHook(); transport.during = { cat.pat(now: third, reports: 0) }
        try await CompanionSync.sync(userID: user, store: CompanionStore(defaults: defaults), transport: transport)
        let saved = try XCTUnwrap(CompanionStore(defaults: defaults).load(owner: owner))
        XCTAssertTrue(saved.growth.patDays.contains("2026-11-03"))
        XCTAssertTrue(saved.needsUpload)
    }

    func testServerShapedGrowthDecodesAndMissingFieldsDefault() throws {
        let full = Data(#"{"name":"Mochi","nameUpdatedAt":500,"metAt":150,"celebratedStage":1,"visitDays":["2026-11-01","2026-11-02"],"patDays":["2026-11-01"],"treatDays":[],"focusMinutes":{"pad":25,"phone":10},"focusSessions":{"pad":1,"phone":1}}"#.utf8)
        let growth = try JSONDecoder().decode(CompanionGrowth.self, from: full)
        XCTAssertEqual(growth.name, "Mochi"); XCTAssertEqual(growth.metAt, Date(timeIntervalSinceReferenceDate: 150))
        XCTAssertEqual(growth.totalFocusMinutes, 35); XCTAssertEqual(growth.celebratedStage, 1)
        let sparse = try JSONDecoder().decode(CompanionGrowth.self, from: Data(#"{"metAt":900}"#.utf8))
        XCTAssertEqual(sparse.name, CompanionState.defaultName); XCTAssertNil(sparse.nameUpdatedAt); XCTAssertTrue(sparse.visitDays.isEmpty)
        // What the app sends: dates as numbers, days as plain strings.
        let sent = try JSONSerialization.jsonObject(with: JSONEncoder().encode(growth)) as? [String: Any]
        XCTAssertTrue(sent?["metAt"] is NSNumber)
        XCTAssertEqual((sent?["visitDays"] as? [String])?.sorted(), ["2026-11-01", "2026-11-02"])
    }

    func testAccountSyncReloadsTheDeskAndDeletingTheAccountErasesTheCat() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(authService: CompanionTestAuth(), storeRoot: root, gradingService: UITestGradingService(), syncTransport: SyncDirectory())
        let defaults = makeDefaults(); model.companionStore = CompanionStore(defaults: defaults)
        await model.syncCompanion()
        XCTAssertEqual(model.companionRevision, 0)
        let loggedIn = await model.verifyCode(email: "a@example.com", code: "123456")
        XCTAssertTrue(loggedIn)
        let owner = try XCTUnwrap(model.account?.userID.uuidString)
        CompanionModel(owner: owner, defaults: defaults, calendar: calendar, now: day(1), deviceID: "phone").recordVisit(now: day(1), reports: 0)
        await model.syncCompanion()
        XCTAssertEqual(model.companionRevision, 1)
        XCTAssertEqual(CompanionStore(defaults: defaults).load(owner: owner)?.needsUpload, false)
        await model.deleteAccount()
        XCTAssertNil(CompanionStore(defaults: defaults).load(owner: owner))
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

/// Runs a closure between the server merge and the local save, like a tap during a slow request.
private final class MergeHook: SyncTransport {
    private let cloud = SyncDirectory()
    var during: @MainActor () -> Void = {}
    func push(userID: UUID, op: SyncOperation) async throws -> SyncPushResult { try await cloud.push(userID: userID, op: op) }
    func pull(userID: UUID, after: Int64) async throws -> [SyncChange] { try await cloud.pull(userID: userID, after: after) }
    func mergeCompanion(userID: UUID, growth: CompanionGrowth) async throws -> CompanionGrowth {
        let merged = try await cloud.mergeCompanion(userID: userID, growth: growth)
        await during()
        return merged
    }
}

private actor CompanionTestAuth: AuthService {
    private var session: AccountSession?
    nonisolated var sessionChanges: AsyncStream<AccountSession?> { AsyncStream { _ in } }
    func currentSession() async throws -> AccountSession? { session }
    func requestCode(email: String) async throws {}
    func verifyCode(email: String, code: String) async throws -> AccountSession {
        let created = AccountSession(userID: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!, email: email)
        session = created
        return created
    }
    func updateEmail(_ email: String) async throws {}
    func signOut() async throws { session = nil }
    func deleteAccount() async throws { session = nil }
}
