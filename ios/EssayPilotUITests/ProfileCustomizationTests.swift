import XCTest

final class ProfileCustomizationTests: XCTestCase {
    @MainActor func testAvatarPickerAndWidgetSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-tab", "profile", "-appearance", "light"]
        app.launch()
        XCTAssertTrue(app.buttons["profile-avatar"].waitForExistence(timeout: 8))
        app.buttons["profile-avatar"].tap()
        app.buttons["avatar-choose"].tap()
        // Seed only tests/fixtures/profile-widget.png via simctl addmedia before this test.
        let chinese = DateFormatter(); chinese.locale = Locale(identifier: "zh_CN"); chinese.dateFormat = "M月"
        let english = DateFormatter(); english.locale = Locale(identifier: "en_US"); english.dateFormat = "MMM"
        let photo = app.images.matching(NSPredicate(format: "identifier == 'PXGGridLayout-Info' AND (label CONTAINS %@ OR label CONTAINS %@)", chinese.string(from: .now), english.string(from: .now))).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8)); photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["恢复默认头像"].waitForExistence(timeout: 8))
        capture("profile-selected-avatar")
        app.navigationBars.buttons.firstMatch.tap()
        let widgets = app.buttons["profile-widgets"]
        for _ in 0..<8 where !widgets.isHittable { app.swipeUp() }
        XCTAssertTrue(widgets.isHittable); widgets.tap()
        let toggle = app.switches["widget-records-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5)); toggle.tap()
        capture("profile-widget-settings")
        app.buttons["widget-background-choose"].tap()
        XCTAssertTrue(photo.waitForExistence(timeout: 8)); photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["背景已保存，桌面小组件会改用这张照片。"].waitForExistence(timeout: 8))
        toggle.tap()
        app.buttons["移除照片背景"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        let avatar = app.buttons["profile-avatar"]
        for _ in 0..<8 where !avatar.isHittable { app.swipeDown() }
        avatar.tap()
        app.buttons["恢复默认头像"].tap()
        app.sheets.buttons["恢复默认头像"].tap()
        XCTAssertTrue(app.buttons["恢复默认头像"].waitForNonExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        capture("profile-formal-light")
    }
    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
