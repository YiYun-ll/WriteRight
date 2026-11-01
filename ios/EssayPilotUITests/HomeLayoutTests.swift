import XCTest

final class HomeLayoutTests: XCTestCase {
    @MainActor func testHomeHasOneRestAreaAndDeskCompanion() {
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
        XCTAssertFalse(app.buttons["home-private-note"].exists)
        XCTAssertFalse(app.staticTexts["在桌边，歇一小会儿"].exists)
        for id in ["home-moment-water", "home-moment-window", "home-moment-closeBook"] { XCTAssertFalse(app.buttons[id].exists) }
        let pat = app.buttons["companion-pat"]
        for _ in 0..<12 where !pat.isHittable { app.swipeUp() }
        XCTAssertTrue(pat.isHittable)
        XCTAssertEqual(app.buttons.matching(identifier: "companion-pat").count, 1)
        XCTAssertLessThanOrEqual(pat.frame.maxX, app.frame.maxX)
        pat.tap()
        XCTAssertTrue(app.staticTexts["companion-line"].label.contains("团团"))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = large ? "home-companion-dark-large" : "home-companion-light"
        shot.lifetime = .keepAlways; add(shot)
        let growth = app.buttons["companion-growth"]
        XCTAssertTrue(growth.waitForExistence(timeout: 5)); growth.tap()
        XCTAssertTrue(app.staticTexts["同行到初试"].waitForExistence(timeout: 5))
        app.buttons["companion-growth-done"].tap()
    }
}
