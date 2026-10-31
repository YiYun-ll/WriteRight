import XCTest

final class HomeRestModeTests: XCTestCase {
    @MainActor func testNightRestWithDarkAccessibilityText() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let rest = app.buttons["home-rest-mode"]
        XCTAssertTrue(rest.waitForExistence(timeout: 10))
        for _ in 0..<4 where !rest.isHittable { app.swipeUp() }
        XCTAssertTrue(rest.isHittable)
        XCTAssertGreaterThanOrEqual(rest.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(rest.frame.maxX, app.frame.maxX)
        rest.tap()
        XCTAssertEqual(rest.value as? String, "休息模式，夜晚")
        XCTAssertEqual(app.buttons["home-lamp"].value as? String, "已关")
        RunLoop.current.run(until: Date().addingTimeInterval(8))
        let night = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        night.name = "home-rest-dark-accessibility"; night.lifetime = .keepAlways; add(night)
        app.buttons["home-lamp"].tap()
        XCTAssertEqual(app.buttons["home-lamp"].value as? String, "亮着")
        rest.tap()
        XCTAssertEqual(rest.value as? String, "白天")
    }

    @MainActor func testSunsetRestTurnsOffLampAndCanReturnToDay() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store",UUID().uuidString,"-appearance","light"]
        app.launch()
        let rest = app.buttons["home-rest-mode"]
        XCTAssertTrue(rest.waitForExistence(timeout:10))
        let daytime = XCTAttachment(screenshot:XCUIScreen.main.screenshot()); daytime.name = "home-rest-day"; daytime.lifetime = .keepAlways; add(daytime)
        rest.tap()
        XCTAssertEqual(rest.value as? String,"休息模式，夜晚")
        XCTAssertEqual(app.buttons["home-lamp"].value as? String,"已关")
        // Allow the actual seven-second illustration animation to finish before recording the night.
        RunLoop.current.run(until:Date().addingTimeInterval(8))
        let night = XCTAttachment(screenshot:XCUIScreen.main.screenshot()); night.name = "home-rest-night"; night.lifetime = .keepAlways; add(night)
        app.buttons["home-lamp"].tap()
        XCTAssertEqual(app.buttons["home-lamp"].value as? String,"亮着")
        XCTAssertTrue(app.staticTexts["home-lamp-response"].label.contains("夜色"))
        rest.tap()
        XCTAssertEqual(rest.value as? String,"白天")
        XCTAssertEqual(app.buttons["home-lamp"].value as? String,"亮着")
    }
}
