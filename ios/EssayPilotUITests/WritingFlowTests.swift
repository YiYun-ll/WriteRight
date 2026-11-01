import XCTest

final class WritingFlowTests: XCTestCase {
    func testWriteRightHomeAndNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light", "-ui-test-today", "2026-10-29"]
        app.launch()
        XCTAssertTrue(app.staticTexts["brand-wordmark"].waitForExistence(timeout: 10))
        let countdown = app.descendants(matching: .any)["exam-countdown"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        XCTAssertTrue(countdown.label.contains("今天"))
        XCTAssertTrue(countdown.label.contains("2026年12月19日"))
        XCTAssertTrue(countdown.label.contains("还有 51 天"))
        XCTAssertTrue(app.staticTexts["exam-note"].label.contains("离初试还有五十一天"))
        XCTAssertFalse(app.buttons["new-part-A"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "WriteRight light home"; attachment.lifetime = .keepAlways
        add(attachment)
        app.tabBars.buttons["练习"].tap()
        XCTAssertTrue(app.buttons["new-part-B"].waitForExistence(timeout: 5))
        let practice = XCTAttachment(screenshot: app.screenshot())
        practice.name = "Practice paper entries"; practice.lifetime = .keepAlways
        add(practice)
        app.tabBars.buttons["练习"].tap()
        app.buttons["practice-history"].tap()
        XCTAssertTrue(app.staticTexts["还没有练习"].waitForExistence(timeout: 5))
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.buttons["profile-practice"].waitForExistence(timeout: 5))
        let profile = XCTAttachment(screenshot: app.screenshot())
        profile.name = "WriteRight serif profile"; profile.lifetime = .keepAlways
        add(profile)
    }

    func testBrandHomeAndAccessibleDarkLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "dark", "-ui-test-today", "2026-12-19", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["brand-wordmark"].waitForExistence(timeout: 10))
        // At accessibility sizes the desk and the cat fill several screens; the home stack is lazy.
        let countdown = app.descendants(matching: .any)["exam-countdown"]
        for _ in 0..<8 where !countdown.exists { app.swipeUp() }
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        XCTAssertTrue(countdown.label.contains("今天"))
        XCTAssertTrue(countdown.label.contains("2026年12月19日"))
        XCTAssertTrue(countdown.label.contains("初试这一天"))
        XCTAssertFalse(app.buttons["new-part-A"].exists)
        XCTAssertTrue(app.tabBars.buttons["记录"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dark accessible home"; attachment.lifetime = .keepAlways
        add(attachment)
        app.tabBars.buttons["练习"].tap()
        let partA = app.buttons["new-part-A"], partB = app.buttons["new-part-B"]
        for _ in 0..<4 where !partA.waitForExistence(timeout: 2) { app.swipeUp() }
        XCTAssertTrue(partA.exists)
        for _ in 0..<4 where !(partB.exists && partB.isHittable) { app.swipeUp() }
        partB.tap()
        XCTAssertTrue(app.navigationBars["大作文"].waitForExistence(timeout: 5))
    }

    func testWriteReturnAndRelaunchKeepsDraft() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["练习"].tap()
        XCTAssertTrue(app.buttons["new-part-A"].waitForExistence(timeout: 10))
        app.buttons["new-part-A"].tap()
        let title = app.textFields["task-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Reading club")
        let prompt = app.textFields["task-prompt"]
        prompt.tap(); prompt.typeText("Invite a friend to a reading club.")
        app.buttons["收起键盘"].tap()
        app.buttons["confirm-task"].tap()
        XCTAssertTrue(app.images["task-confirmed"].waitForExistence(timeout: 5))
        let body = app.textViews["essay-body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5))
        body.tap(); body.typeText("Dear Alex,\nI would like to invite you to our reading club.")
        app.buttons["finish-editing"].tap()
        XCTAssertTrue(app.staticTexts["Reading club"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.tabBars.buttons["练习"].tap()
        XCTAssertTrue(app.staticTexts["continue-title"].waitForExistence(timeout: 10))
        app.staticTexts["continue-title"].firstMatch.tap()
        XCTAssertTrue(app.textViews["essay-body"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textViews["essay-body"].value as? String ?? "").contains("Dear Alex"))
        XCTAssertTrue(app.images["task-confirmed"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Persisted writing draft"; attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testBackgroundingSavesWithoutPressingDone() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["练习"].tap()
        XCTAssertTrue(app.buttons["new-part-B"].waitForExistence(timeout: 10))
        app.buttons["new-part-B"].tap()
        let title = app.textFields["task-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Unfinished draft")
        app.staticTexts["题目"].firstMatch.tap()
        let body = app.textViews["essay-body"]
        body.tap(); body.typeText("The chart shows a steady rise.")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.terminate(); app.launch()
        app.tabBars.buttons["练习"].tap()
        XCTAssertTrue(app.staticTexts["continue-title"].waitForExistence(timeout: 10))
        app.staticTexts["continue-title"].firstMatch.tap()
        XCTAssertTrue(app.textViews["essay-body"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textViews["essay-body"].value as? String ?? "").contains("steady rise"))
    }

    func testHistorySearchAndPartFilter() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch()
        app.tabBars.buttons["练习"].tap()
        for (part, name) in [("A", "Reading club"), ("B", "Online learning")] {
            XCTAssertTrue(app.buttons["new-part-\(part)"].waitForExistence(timeout: 10))
            app.buttons["new-part-\(part)"].tap()
            let title = app.textFields["task-title"]
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            title.tap(); title.typeText(name)
            app.buttons["finish-editing"].tap()
        }
        app.tabBars.buttons["练习"].tap()
        app.buttons["practice-history"].tap()
        XCTAssertTrue(app.staticTexts["Reading club"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Online learning"].exists)
        app.segmentedControls.buttons["大作文"].tap()
        XCTAssertFalse(app.staticTexts["Reading club"].exists)
        XCTAssertTrue(app.staticTexts["Online learning"].exists)
        app.segmentedControls.buttons["全部"].tap()
        app.swipeDown()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("Reading")
        XCTAssertTrue(app.staticTexts["Reading club"].exists)
        XCTAssertFalse(app.staticTexts["Online learning"].exists)
    }

    func testManualEditorCanSwitchToDirectPhotoPractice() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString]
        app.launch()
        app.tabBars.buttons["练习"].tap()
        app.buttons["new-part-A"].tap()
        app.buttons["open-scan"].tap()
        XCTAssertTrue(app.buttons["photo-album-task"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textViews["scan-transcript-0"].exists)
    }
}
