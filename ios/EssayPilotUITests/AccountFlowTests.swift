import XCTest

final class AccountFlowTests: XCTestCase {
    func testLoginMigrationAndAccountPrivacy() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch()
        app.tabBars.buttons["练习"].tap()
        XCTAssertTrue(app.buttons["practice-part-A"].waitForExistence(timeout: 10))
        app.buttons["practice-part-A"].tap()
        app.buttons["start-A"].tap()
        let title = app.textFields["task-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("本机草稿")
        app.buttons["保存并返回"].tap()

        app.tabBars.buttons["我的"].tap()
        app.buttons["login-link"].tap()
        let email = app.textFields["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap(); email.typeText("a@example.com")
        app.buttons["auth-send"].tap()
        let code = app.textFields["auth-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.tap(); code.typeText("123456")
        let login = XCTAttachment(screenshot: app.screenshot())
        login.name = "P4 glass OTP login"; login.lifetime = .keepAlways
        add(login)
        app.buttons["auth-verify"].tap()

        XCTAssertTrue(app.buttons["migrate-guest-drafts"].waitForExistence(timeout: 5))
        app.buttons["migrate-guest-drafts"].tap()
        app.tabBars.buttons["练习"].tap()
        XCTAssertTrue(app.staticTexts["本机草稿"].waitForExistence(timeout: 5))

        app.tabBars.buttons["我的"].tap()
        app.buttons["account-link"].tap()
        XCTAssertTrue(app.buttons["退出登录"].waitForExistence(timeout: 5))
        app.buttons["退出登录"].tap()
        app.sheets.buttons["退出登录"].tap()
        XCTAssertTrue(app.buttons["login-link"].waitForExistence(timeout: 5))
        app.tabBars.buttons["练习"].tap()
        XCTAssertFalse(app.staticTexts["本机草稿"].waitForExistence(timeout: 2))
    }
}
