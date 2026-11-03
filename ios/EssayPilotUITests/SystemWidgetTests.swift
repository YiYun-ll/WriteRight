import XCTest

final class SystemWidgetTests: XCTestCase {
    @MainActor func testLiveActivity() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch()
        let focus = app.buttons["companion-focus"]
        for _ in 0..<8 where !focus.isHittable { app.swipeUp() }
        XCTAssertTrue(focus.waitForExistence(timeout: 5)); focus.tap(); app.buttons["25 分钟"].tap()
        XCTAssertTrue(app.buttons["companion-focus-end"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(springboard.icons["WriteRight"].firstMatch.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 1)
        capture("focus-island-compact")
        let island = springboard.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'jindo-container-view'")).firstMatch
        if island.waitForExistence(timeout: 3) {
            island.press(forDuration: 1.2); capture("focus-island-expanded")
            springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.6)).tap()
        }
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.01)).press(forDuration: 0.1, thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)))
        if springboard.buttons["允许"].exists { springboard.buttons["允许"].tap() }
        capture("focus-lock-screen")
        XCUIDevice.shared.press(.home)
        app.activate()
        app.buttons["companion-focus-end"].tap()
    }
    @MainActor func testSystemWidgetConfiguration() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch()
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons["WriteRight"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 5))
        icon.press(forDuration: 1.5)
        capture("widget-menu")
        let small = springboard.buttons["小型小组件"]
        XCTAssertTrue(small.waitForExistence(timeout: 5)); small.tap()
        Thread.sleep(forTimeInterval: 3)
        capture("widget-countdown-small")
        let widget = springboard.icons["WriteRight"].firstMatch
        XCTAssertEqual(widget.value as? String, "小组件")

    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
