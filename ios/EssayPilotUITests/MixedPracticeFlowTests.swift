import XCTest

final class MixedPracticeFlowTests: XCTestCase {
    @MainActor private func app() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-tab", "practice", "-ui-test-photos"]
        app.launch(); XCTAssertTrue(app.buttons["start-photo-practice"].waitForExistence(timeout: 15))
        return app
    }
    @MainActor private func login(_ app: XCUIApplication) {
        let button = app.buttons["photo-login"]
        XCTAssertTrue(button.waitForExistence(timeout: 8)); button.tap()
        let email = app.textFields["auth-email"]; XCTAssertTrue(email.waitForExistence(timeout: 5)); email.tap(); email.typeText("mixed@example.com")
        app.buttons["auth-send"].tap()
        let code = app.textFields["auth-code"]; XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("123456")
        app.buttons["auth-verify"].tap()
        XCTAssertTrue(app.buttons["photo-submit"].waitForExistence(timeout: 10))
    }
    @MainActor func testTextTaskAndPhotoAnswerThenRemoveReuseShortcut() {
        let app = app(); app.buttons["start-photo-practice"].tap()
        app.buttons["photo-load-sample"].tap()
        app.segmentedControls["practice-input-task"].buttons["文字"].tap()
        let prompt = app.textFields["task-prompt"]; prompt.tap(); prompt.typeText("Invite Alex to a museum.")
        app.buttons["收起键盘"].tap()
        login(app); app.buttons["photo-submit"].tap()
        let report = app.buttons["photo-open-report"]; XCTAssertTrue(report.waitForExistence(timeout: 20)); report.tap()
        XCTAssertTrue(app.otherElements["report-view"].waitForExistence(timeout: 5))
        app.buttons["close-report"].tap(); app.buttons["先去做别的"].tap()
        let menu = app.buttons["reuse-task-menu"]
        for _ in 0..<7 where !menu.isHittable { app.swipeUp() }
        XCTAssertTrue(menu.isHittable); menu.tap(); app.buttons["移除再练入口"].tap()
        XCTAssertTrue(app.buttons["undo-removal"].waitForExistence(timeout: 5)); app.buttons["undo-removal"].tap()
        XCTAssertTrue(app.buttons["reuse-task"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "practice-reuse-removal-undo"; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor func testPhotoTaskAndTypedAnswer() {
        let app = app(); app.buttons["start-photo-practice"].tap(); app.buttons["photo-load-sample"].tap()
        let choice = app.segmentedControls["practice-input-essay"]
        for _ in 0..<5 where !choice.isHittable { app.swipeUp() }
        choice.buttons["文字"].tap()
        let body = app.textViews["essay-body"]
        for _ in 0..<4 where !body.isHittable { app.swipeUp() }
        body.tap(); body.typeText("I has a book. It is useful."); app.buttons["收起键盘"].tap()
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = "practice-photo-task-typed-answer"; attachment.lifetime = .keepAlways; add(attachment)
        login(app); app.buttons["photo-submit"].tap()
        XCTAssertTrue(app.buttons["photo-open-report"].waitForExistence(timeout: 20))
    }
    @MainActor func testDraftDeleteUndoAndModeSwitchKeepsText() {
        let app = app(); app.buttons["start-A"].tap()
        let prompt = app.textFields["task-prompt"]; XCTAssertTrue(prompt.waitForExistence(timeout: 5)); prompt.tap(); prompt.typeText("My saved task."); app.buttons["收起键盘"].tap()
        app.segmentedControls["practice-input-task"].buttons["照片"].tap()
        app.segmentedControls["practice-input-task"].buttons["文字"].tap()
        XCTAssertEqual(prompt.value as? String, "My saved task.")
        app.buttons["保存并返回"].tap()
        let menu = app.buttons["continue-draft-menu"]
        for _ in 0..<6 where !menu.isHittable { app.swipeUp() }
        XCTAssertTrue(menu.isHittable); menu.tap(); app.buttons["删除草稿"].tap()
        XCTAssertTrue(app.buttons["undo-removal"].waitForExistence(timeout: 5)); app.buttons["undo-removal"].tap()
        XCTAssertTrue(app.buttons["continue-draft"].exists)
        app.buttons["continue-draft-menu"].tap(); app.buttons["删除草稿"].tap()
        XCUIDevice.shared.press(.home)
        app.terminate(); app.launch()
        XCTAssertFalse(app.buttons["continue-draft"].exists)
    }
}
