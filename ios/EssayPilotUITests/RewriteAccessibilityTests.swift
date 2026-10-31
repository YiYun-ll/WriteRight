import XCTest

final class RewriteAccessibilityTests: XCTestCase {
    @MainActor func testPhotoRewriteTranslationAndFocusWithDarkLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store",UUID().uuidString,"-ui-test-tab","practice","-ui-test-photos","-appearance","dark","-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let start = app.buttons["start-photo-practice"]
        XCTAssertTrue(start.waitForExistence(timeout: 10)); start.tap()
        app.buttons["photo-load-sample"].tap()
        let login = app.buttons["photo-login"]
        XCTAssertTrue(login.waitForExistence(timeout: 8)); login.tap()
        let email = app.textFields["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5)); email.tap(); email.typeText("rewrite@example.com")
        app.buttons["auth-send"].tap()
        let code = app.textFields["auth-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("123456")
        app.buttons["auth-verify"].tap()
        let submit = app.buttons["photo-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 8)); submit.tap()
        let open = app.buttons["photo-open-report"]
        XCTAssertTrue(open.waitForExistence(timeout: 12))
        for _ in 0..<5 where !open.isHittable { app.swipeUp() }
        open.tap()
        let section = app.buttons["report-section-rewrites"]
        XCTAssertTrue(section.waitForExistence(timeout: 5)); section.tap()
        let english = app.staticTexts["rewrite-english"]
        for _ in 0..<7 where !english.isHittable { app.swipeUp() }
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(english.frame.maxX, app.frame.maxX)
        let focus = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); focus.name = "rewrite-dark-accessibility-focus"; focus.lifetime = .keepAlways; add(focus)
        let translation = app.staticTexts["rewrite-translation"]
        for _ in 0..<8 where !translation.isHittable { app.swipeUp() }
        XCTAssertTrue(translation.waitForExistence(timeout: 5))
        XCTAssertTrue((translation.label).contains("我有一本书"))
        let picker = app.buttons["rewrite-version"]
        for _ in 0..<12 where !picker.isHittable { app.swipeDown() }
        XCTAssertTrue(picker.exists); picker.tap()
        app.buttons["满分示范"].tap()
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        XCTAssertTrue(english.label.contains("Dear Alex"))
        XCTAssertLessThanOrEqual(english.frame.maxX, app.frame.maxX)
        let model = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); model.name = "model-essay-dark-accessibility"; model.lifetime = .keepAlways; add(model)
        for _ in 0..<14 where !translation.isHittable { app.swipeUp() }
        XCTAssertTrue(translation.waitForExistence(timeout: 5))
        XCTAssertTrue(translation.label.contains("博物馆"))
        let chinese = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); chinese.name = "rewrite-dark-accessibility-translation"; chinese.lifetime = .keepAlways; add(chinese)
    }
}
