import XCTest

final class TranslationFlowTests: XCTestCase {
    @MainActor func testTranslationPhotoFlowAndQuarterPointReport() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-tab", "practice", "-ui-test-photos"]
        app.launch()
        let translation = app.buttons["practice-part-T"]
        XCTAssertTrue(translation.waitForExistence(timeout: 15)); translation.tap()
        let landing = XCTAttachment(screenshot: app.screenshot()); landing.name = "translation-practice-light"; landing.lifetime = .keepAlways; add(landing)
        app.buttons["start-photo-practice"].tap()
        XCTAssertTrue(app.staticTexts["英文原文"].waitForExistence(timeout: 5))
        app.buttons["photo-load-sample"].tap()
        app.buttons["photo-login"].tap()
        let email = app.textFields["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5)); email.tap(); email.typeText("translation@example.com")
        app.buttons["auth-send"].tap()
        let code = app.textFields["auth-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("123456")
        app.buttons["auth-verify"].tap()
        let submit = app.buttons["photo-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 10)); submit.tap()
        let report = app.buttons["photo-open-report"]
        XCTAssertTrue(report.waitForExistence(timeout: 20)); report.tap()
        XCTAssertTrue(app.staticTexts["14.75"].waitForExistence(timeout: 5))
        app.buttons["report-section-sentences"].tap()
        XCTAssertTrue(app.staticTexts["英文原句"].firstMatch.waitForExistence(timeout: 5))
        let sentences = XCTAttachment(screenshot: app.screenshot()); sentences.name = "translation-sentence-analysis"; sentences.lifetime = .keepAlways; add(sentences)
        app.buttons["report-section-rewrites"].tap()
        XCTAssertTrue(app.staticTexts["translation-revision"].waitForExistence(timeout: 5))
        app.buttons["translation-copy"].tap()
        XCTAssertTrue(app.buttons["translation-copy"].label.contains("已复制"))
    }

    @MainActor func testDarkLargeTypeSelectsTranslationAndOpensTextInput() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-tab", "practice", "-appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let translation = app.buttons["practice-part-T"]
        XCTAssertTrue(translation.waitForExistence(timeout: 15))
        for _ in 0..<4 where !translation.isHittable { app.swipeUp() }
        translation.tap()
        let text = app.buttons["start-T"]
        for _ in 0..<6 where !text.isHittable { app.swipeUp() }
        XCTAssertTrue(text.isHittable); XCTAssertLessThanOrEqual(text.frame.maxX, app.frame.maxX)
        let landing = XCTAttachment(screenshot: app.screenshot()); landing.name = "translation-practice-dark-accessibility"; landing.lifetime = .keepAlways; add(landing)
        text.tap()
        XCTAssertTrue(app.navigationBars["翻译"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["essay-body"].exists)
    }
}
