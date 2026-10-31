import XCTest

final class LoginFailureTests: XCTestCase {
    @MainActor func testConnectionFailureShowsSafeDiagnosticAndAllowsRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-tab", "profile", "-ui-test-auth-network-failure"]
        app.launch()
        app.tabBars.buttons["我的"].tap()
        let login = app.buttons["login-link"]
        XCTAssertTrue(login.waitForExistence(timeout: 10)); login.tap()
        let email = app.textFields["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5)); email.tap(); email.typeText("test@example.com")
        app.buttons["auth-send"].tap()
        let error = app.staticTexts["auth-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertTrue(error.label.contains("安全连接失败"))
        XCTAssertTrue(error.label.contains("-1200"))
        XCTAssertTrue(app.buttons["auth-send"].isEnabled)
        XCTAssertFalse(app.textFields["auth-code"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "login-network-diagnostic"; shot.lifetime = .keepAlways; add(shot)
    }
}
