import XCTest

final class NicknameFlowTests: XCTestCase {
    @MainActor func testNicknameEditShowsOnProfileAndCanBeReset() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store",UUID().uuidString,"-ui-test-tab","profile"]
        app.launch()
        let login = app.buttons["login-link"]
        XCTAssertTrue(login.waitForExistence(timeout:10)); login.tap()
        let email = app.textFields["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout:5)); email.tap(); email.typeText("nickname@example.com")
        app.buttons["auth-send"].tap()
        let code = app.textFields["auth-code"]
        XCTAssertTrue(code.waitForExistence(timeout:5)); code.tap(); code.typeText("123456")
        app.buttons["auth-verify"].tap()
        let edit = app.buttons["profile-edit-nickname"]
        XCTAssertTrue(edit.waitForExistence(timeout:8)); edit.tap()
        let field = app.textFields["nickname-field"]
        XCTAssertTrue(field.waitForExistence(timeout:5)); field.tap(); field.typeText("Morning Pages")
        app.buttons["nickname-save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout:8)); XCTAssertTrue(edit.label.contains("Morning Pages"))
        let shot = XCTAttachment(screenshot:XCUIScreen.main.screenshot()); shot.name = "profile-nickname"; shot.lifetime = .keepAlways; add(shot)
        edit.tap(); XCTAssertTrue(field.waitForExistence(timeout:5))
        XCTAssertEqual(field.value as? String,"Morning Pages")
        field.tap(); field.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:13))
        app.buttons["nickname-save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout:8)); XCTAssertTrue(edit.label.contains("尚未设置"))
    }
}
