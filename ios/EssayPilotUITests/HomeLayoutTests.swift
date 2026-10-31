import XCTest

final class HomeLayoutTests: XCTestCase {
    @MainActor func testHomeHasOneRestAreaAndKeepsPrivateNote() {
        verifyHome(large: false)
    }
    @MainActor func testDarkLargeHomeHasNoLegacyRestPanel() {
        verifyHome(large: true)
    }
    @MainActor private func verifyHome(large: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", large ? "dark" : "light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let rest = app.buttons["home-rest-mode"]
        XCTAssertTrue(rest.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "home-rest-mode").count, 1)
        let note = app.buttons["home-private-note"]
        for _ in 0..<30 where !note.isHittable { app.swipeUp() }
        XCTAssertTrue(note.isHittable)
        XCTAssertEqual(app.buttons.matching(identifier: "home-private-note").count, 1)
        XCTAssertFalse(app.staticTexts["在桌边，歇一小会儿"].exists)
        for id in ["home-moment-water", "home-moment-window", "home-moment-closeBook"] { XCTAssertFalse(app.buttons[id].exists) }
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = large ? "home-single-rest-dark-large" : "home-single-rest-private-note"
        shot.lifetime = .keepAlways; add(shot)
        note.tap(); XCTAssertTrue(app.textFields["desk-note-text"].waitForExistence(timeout: 5))
        app.buttons["desk-note-done"].tap()
    }
}
