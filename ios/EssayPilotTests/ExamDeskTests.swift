import XCTest
@testable import EssayPilot

final class ExamDeskTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testDaysRemainingCountWholeLocalDaysUntilDecember19() {
        let desk = ExamDesk(calendar: calendar)
        XCTAssertEqual(desk.daysRemaining(on: date(2026, 10, 29)), 51)
        XCTAssertEqual(desk.daysRemaining(on: date(2026, 12, 18, 23, 30)), 1)
        XCTAssertEqual(desk.daysRemaining(on: date(2026, 12, 19, 0, 30)), 0)
        XCTAssertEqual(desk.daysRemaining(on: date(2026, 12, 20, 0, 5)), -1)
        XCTAssertEqual(desk.daysRemaining(on: date(2026, 11, 1)), 48)
        XCTAssertEqual(desk.daysRemaining(on: date(2026, 12, 1)), 18)
    }

    func testEachRemainingDayThroughExamHasItsOwnNote() {
        let desk = ExamDesk(calendar: calendar)
        var seen = Set<String>()
        for day in 0...51 {
            let note = desk.note(daysRemaining: day)
            XCTAssertGreaterThan(note.count, 70, "day \(day) needs a considered letter")
            XCTAssertTrue(seen.insert(note).inserted, "duplicate note on day \(day): \(note)")
            XCTAssertFalse(note.contains("加油"), note)
            XCTAssertFalse(note.contains("！"), note)
        }
        XCTAssertEqual(desk.note(daysRemaining: 80), desk.note(daysRemaining: 52))
        XCTAssertNotEqual(desk.note(daysRemaining: 52), desk.note(daysRemaining: 51))
        XCTAssertEqual(desk.note(daysRemaining: -4), desk.note(daysRemaining: -1))
        XCTAssertNotEqual(desk.note(daysRemaining: -1), desk.note(daysRemaining: 0))
        XCTAssertTrue(desk.note(daysRemaining: 48).contains("十一月"))
        XCTAssertTrue(desk.note(daysRemaining: 18).contains("十二月"))
    }

    func testSnapshotShowsNumberOnlyBeforeExamDay() {
        let desk = ExamDesk(calendar: calendar)
        let before = desk.snapshot(on: date(2026, 10, 29))
        XCTAssertEqual(before.daysRemaining, 51)
        XCTAssertTrue(before.showsNumber)
        XCTAssertEqual(before.headline, "还有 51 天")
        XCTAssertEqual(before.dateLine, "12月19日 初试")
        XCTAssertEqual(before.accessibilityLabel, "距离初试还有 51 天，12月19日")
        XCTAssertEqual(before.note, desk.note(daysRemaining: 51))

        let exam = desk.snapshot(on: date(2026, 12, 19))
        XCTAssertFalse(exam.showsNumber)
        XCTAssertEqual(exam.headline, "初试这一天")
        XCTAssertEqual(exam.dateLine, "12月19日 初试")
        XCTAssertEqual(exam.accessibilityLabel, "初试这一天，12月19日")

        let after = desk.snapshot(on: date(2026, 12, 21))
        XCTAssertFalse(after.showsNumber)
        XCTAssertEqual(after.headline, "")
        XCTAssertEqual(after.dateLine, "")
        XCTAssertEqual(after.accessibilityLabel, after.note)
    }
}
