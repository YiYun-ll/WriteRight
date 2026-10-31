import XCTest

final class DevelopmentFlowTests: XCTestCase {
    @MainActor func testPhotoReportHasSentenceStructureAndIndependentExample() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-tab", "practice", "-ui-test-photos", "-appearance", "light"]
        app.launch(); app.buttons["start-photo-practice"].tap()
        app.buttons["photo-load-sample"].tap()
        let login = app.buttons["photo-login"]
        XCTAssertTrue(login.waitForExistence(timeout: 8)); login.tap()
        let email = app.textFields["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5)); email.tap(); email.typeText("study@example.com")
        app.buttons["auth-send"].tap()
        let code = app.textFields["auth-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("123456")
        app.buttons["auth-verify"].tap()
        let submit = app.buttons["photo-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 8)); submit.tap()
        let report = app.buttons["photo-open-report"]
        XCTAssertTrue(report.waitForExistence(timeout: 12)); report.tap()
        app.buttons["report-section-sentences"].tap()
        let firstSentence = app.staticTexts["I have a book."]
        for _ in 0..<8 where !firstSentence.isHittable { app.swipeUp() }
        XCTAssertTrue(firstSentence.exists)
        XCTAssertTrue(app.staticTexts["为什么"].firstMatch.exists)
        let kept = app.staticTexts["值得保留"]
        for _ in 0..<4 where !kept.isHittable { app.swipeUp() }
        XCTAssertTrue(kept.exists)
        let sentences = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); sentences.name = "report-sentence-reviews"; sentences.lifetime = .keepAlways; add(sentences)
        let sentence = app.descendants(matching: .any)["advice-sentence"]
        for _ in 0..<8 where !sentence.isHittable { app.swipeUp() }
        XCTAssertTrue(sentence.exists)
        let structure = app.descendants(matching: .any)["advice-structure"]
        for _ in 0..<5 where !structure.isHittable { app.swipeUp() }
        XCTAssertTrue(structure.exists)
        let advice = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); advice.name = "report-advanced-advice"; advice.lifetime = .keepAlways; add(advice)
        app.buttons["report-section-rewrites"].tap()
        app.segmentedControls["rewrite-version"].buttons["满分示范"].tap()
        XCTAssertTrue(app.staticTexts["rewrite-english"].waitForExistence(timeout: 5))
        let copy = app.buttons["rewrite-copy"]
        for _ in 0..<5 where !copy.isHittable { app.swipeDown() }
        copy.tap(); XCTAssertTrue(app.buttons["已复制"].exists)
        Thread.sleep(forTimeInterval: 0.5) // Capture settled feedback, after the label transition.
        let english = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); english.name = "report-model-essay"; english.lifetime = .keepAlways; add(english)
        let translation = app.staticTexts["rewrite-translation"]
        for _ in 0..<10 where !translation.isHittable { app.swipeUp() }
        XCTAssertTrue(translation.exists)
        let chinese = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); chinese.name = "report-model-translation"; chinese.lifetime = .keepAlways; add(chinese)
    }
}
