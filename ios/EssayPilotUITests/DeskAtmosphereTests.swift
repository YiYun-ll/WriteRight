import XCTest

final class DeskAtmosphereTests: XCTestCase {
    @MainActor func testWindowTeaPlantAndRestAreInteractive() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch()
        let window = app.buttons["home-window"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.tap(); XCTAssertEqual(window.value as? String, "窗边微风")
        XCTAssertTrue(app.staticTexts["home-lamp-response"].label.contains("风"))
        window.tap(); XCTAssertEqual(window.value as? String, "窗边小雨")
        Thread.sleep(forTimeInterval: 3.3)
        attach("home-window-rain")
        app.buttons["home-tea"].tap(); XCTAssertEqual(app.buttons["home-tea"].value as? String, "茶还温着")
        XCTAssertTrue(app.staticTexts["home-lamp-response"].label.contains("茶气"))
        app.buttons["home-plant"].tap(); XCTAssertTrue(app.buttons["home-plant"].value as? String == "已照料小画里的绿植")
        XCTAssertTrue(app.staticTexts["home-lamp-response"].label.contains("叶子"))
        let rest = app.buttons["home-rest-mode"]; rest.tap()
        XCTAssertEqual(app.buttons["home-lamp"].value as? String, "已关")
        XCTAssertEqual(window.value as? String, "窗边小雨")
        Thread.sleep(forTimeInterval: 7.3)
        attach("home-rain-night")
        rest.tap(); window.tap(); XCTAssertEqual(window.value as? String, "窗外安静")
        app.terminate(); app.launch()
        XCTAssertTrue(window.waitForExistence(timeout: 10)); XCTAssertEqual(window.value as? String, "窗外安静")
        XCTAssertEqual(app.buttons["home-tea"].value as? String, "等你添茶")
    }
    @MainActor func testDarkLargeDeskControlsStayWithinScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let window = app.buttons["home-window"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        for id in ["home-window", "home-tea", "home-plant"] {
            let button = app.buttons[id]
            for _ in 0..<7 where !button.isHittable { app.swipeUp() }
            XCTAssertTrue(button.isHittable); XCTAssertGreaterThanOrEqual(button.frame.minX, 0)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.maxX)
            button.tap()
        }
        attach("home-desk-dark-accessibility")
    }
    @MainActor private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
