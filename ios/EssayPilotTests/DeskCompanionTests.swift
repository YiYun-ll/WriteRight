import XCTest
@testable import EssayPilot

@MainActor final class DeskCompanionTests: XCTestCase {
    func testPrivateNoteSurvivesReopeningAndStaysSeparateAcrossOwners() throws {
        let name = "desk-tests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = DeskCompanionModel(owner: "first", defaults: defaults)
        first.note = "今天把结尾写清楚了。"
        let second = DeskCompanionModel(owner: "second", defaults: defaults)
        XCTAssertEqual(second.note, "")
        second.note = "早点休息。"
        XCTAssertEqual(DeskCompanionModel(owner: "first", defaults: defaults).note, first.note)
        DeskCompanionModel.erase(owner: "first", defaults: defaults)
        XCTAssertEqual(DeskCompanionModel(owner: "first", defaults: defaults).note, "")
        XCTAssertEqual(DeskCompanionModel(owner: "second", defaults: defaults).note, "早点休息。")
        second.clear()
        XCTAssertEqual(DeskCompanionModel(owner: "second", defaults: defaults).note, "")
    }
}
