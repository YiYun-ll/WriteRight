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

extension SystemWidgetTests {
    @MainActor func testCustomPhotoWidgetRendersOnSpringboard() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Uses the simulator's seeded synthetic photo and Home Screen.")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-tab", "profile", "-appearance", "light"]
        app.launch()
        let settings = app.buttons["profile-widgets"]
        for _ in 0..<8 where !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.isHittable); settings.tap(); app.buttons["widget-background-choose"].tap()
        let chinese = DateFormatter(); chinese.locale = Locale(identifier: "zh_CN"); chinese.dateFormat = "M月"
        let photo = app.images.matching(NSPredicate(format: "identifier == 'PXGGridLayout-Info' AND label CONTAINS %@", chinese.string(from: .now))).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8)); photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["背景已保存，桌面小组件会改用这张照片。"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons["WriteRight"].firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 8))
        icon.press(forDuration: 1.5)
        if springboard.buttons["小型小组件"].exists { springboard.buttons["小型小组件"].tap() }
        else { springboard.tap() }
        let widget = springboard.icons["WriteRight"].firstMatch
        XCTAssertEqual(widget.value as? String, "小组件")
        Thread.sleep(forTimeInterval: 3)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = "widget-custom-photo-real-springboard"; attachment.lifetime = .keepAlways; add(attachment)
        app.activate(); app.buttons["移除照片背景"].tap()
        #endif
    }
}
