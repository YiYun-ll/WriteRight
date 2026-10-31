import XCTest

final class PhotoPracticeFlowTests: XCTestCase {
    @MainActor func testPhysicalCloudSessionSurvivesRelaunch() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires a real device with the owner's completed email login.")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-tab", "profile"]
        app.launch()
        XCTAssertTrue(app.buttons["account-link"].waitForExistence(timeout: 20))
        app.buttons["sync-now"].tap()
        XCTAssertTrue(app.staticTexts["已同步"].waitForExistence(timeout: 30))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["account-link"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["login-link"].exists)
        #endif
    }

    @MainActor func testDarkAccessibilityPhotoInputsStayWithinScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-tab", "practice", "-appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let start = app.buttons["start-photo-practice"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        let landing = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landing.name = "photo-practice-dark-accessibility"; landing.lifetime = .keepAlways; add(landing)
        start.tap()
        let essay = app.buttons["photo-album-essay"]
        XCTAssertTrue(essay.waitForExistence(timeout: 5))
        for _ in 0..<5 where !essay.isHittable { app.swipeUp() }
        XCTAssertTrue(essay.isHittable)
        XCTAssertLessThanOrEqual(essay.frame.maxX, app.frame.maxX)
        let upload = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        upload.name = "photo-upload-dark-accessibility"; upload.lifetime = .keepAlways; add(upload)
    }

    @MainActor func testPhotosGoStraightToGradingAndOriginalImageReport() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-tab", "practice", "-ui-test-photos"]
        app.launch()
        let start = app.buttons["start-photo-practice"]
        XCTAssertTrue(start.waitForExistence(timeout: 15)); start.tap()
        app.buttons["photo-load-sample"].tap()
        let login = app.buttons["photo-login"]
        XCTAssertTrue(login.waitForExistence(timeout: 10)); login.tap()
        let email = app.textFields["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5)); email.tap(); email.typeText("photo@example.com")
        app.buttons["auth-send"].tap()
        let code = app.textFields["auth-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5)); code.tap(); code.typeText("123456")
        app.buttons["auth-verify"].tap()
        let submit = app.buttons["photo-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 10))
        XCTAssertFalse(app.textViews["photo-essay-text"].exists)
        let upload = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); upload.name = "direct-photo-upload"; upload.lifetime = .keepAlways; add(upload)
        submit.tap()
        XCTAssertTrue(app.otherElements["reading-progress"].waitForExistence(timeout: 10))
        let open = app.buttons["photo-open-report"]
        XCTAssertTrue(open.waitForExistence(timeout: 20))
        let ready = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); ready.name = "direct-photo-ready"; ready.lifetime = .keepAlways; add(ready)
        open.tap()
        XCTAssertTrue(app.buttons["report-section-sentences"].waitForExistence(timeout: 5))
        let overview = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); overview.name = "direct-photo-overview"; overview.lifetime = .keepAlways; add(overview)
        app.buttons["report-section-sentences"].tap()
        XCTAssertTrue(app.buttons["放大作文第1页"].waitForExistence(timeout: 10))
        let advice = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); advice.name = "direct-photo-original-advice"; advice.lifetime = .keepAlways; add(advice)
        app.buttons["report-section-review"].tap()
        XCTAssertTrue(app.staticTexts["下一次练习"].waitForExistence(timeout: 5))
        app.buttons["close-report"].tap()
        app.buttons["先去做别的"].tap()
        let reuse = app.buttons["reuse-task"].firstMatch
        for _ in 0..<6 where !reuse.isHittable { app.swipeUp() }
        XCTAssertTrue(reuse.waitForExistence(timeout: 5)); reuse.tap()
        app.buttons["photo-load-sample"].tap()
        let secondSubmit = app.buttons["photo-submit"]
        XCTAssertTrue(secondSubmit.waitForExistence(timeout: 5)); secondSubmit.tap()
        XCTAssertTrue(app.buttons["photo-open-report"].waitForExistence(timeout: 15))
        app.buttons["先去做别的"].tap()
        app.tabBars.buttons["练习"].tap()
        app.buttons["practice-history"].tap()
        app.buttons["对比"].tap()
        XCTAssertTrue(app.staticTexts["上一次"].waitForExistence(timeout: 5))
        let compare = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); compare.name = "direct-photo-comparison"; compare.lifetime = .keepAlways; add(compare)
        app.terminate(); app.launch()
        // Fixture sessions are intentionally memory-only; sign back into the same test owner.
        app.tabBars.buttons["我的"].tap()
        app.buttons["login-link"].tap()
        let again = app.textFields["auth-email"]
        XCTAssertTrue(again.waitForExistence(timeout: 5)); again.tap(); again.typeText("photo@example.com")
        app.buttons["auth-send"].tap()
        let againCode = app.textFields["auth-code"]
        XCTAssertTrue(againCode.waitForExistence(timeout: 5)); againCode.tap(); againCode.typeText("123456")
        app.buttons["auth-verify"].tap()
        app.tabBars.buttons["练习"].tap()
        let restored = app.buttons["recent-report"].firstMatch
        for _ in 0..<8 where !restored.isHittable { app.swipeUp() }
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        app.tabBars.buttons["练习"].tap()
        app.buttons["practice-history"].tap()
        app.buttons["成绩"].tap()
        XCTAssertTrue(app.staticTexts["一篇一篇，留下自己的刻度。"].waitForExistence(timeout: 5))
        let stats = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); stats.name = "direct-photo-stats-first-score"; stats.lifetime = .keepAlways; add(stats)
    }
}
