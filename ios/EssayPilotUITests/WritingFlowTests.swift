import XCTest

final class WritingFlowTests: XCTestCase {
    func testWriteRightHomeAndNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch()
        XCTAssertTrue(app.navigationBars["WriteRight"].waitForExistence(timeout: 10))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "WriteRight light home"; attachment.lifetime = .keepAlways
        add(attachment)
        app.tabBars.buttons["练习"].tap()
        XCTAssertTrue(app.buttons["new-part-B"].exists)
        app.tabBars.buttons["历史"].tap()
        XCTAssertTrue(app.staticTexts["还没有练习"].waitForExistence(timeout: 5))
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.staticTexts["WriteRight"].waitForExistence(timeout: 5))
    }

    func testBrandHomeAndAccessibleDarkLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["new-part-A"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["new-part-B"].exists)
        XCTAssertTrue(app.tabBars.buttons["历史"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dark accessible home"; attachment.lifetime = .keepAlways
        add(attachment)
        app.swipeUp()
        app.buttons["new-part-B"].tap()
        XCTAssertTrue(app.navigationBars["大作文"].waitForExistence(timeout: 5))
    }

    func testWriteReturnAndRelaunchKeepsDraft() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString]
        app.launch()
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
        XCTAssertTrue(app.staticTexts["Reading club"].waitForExistence(timeout: 10))
        app.staticTexts["Reading club"].firstMatch.tap()
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
        XCTAssertTrue(app.staticTexts["Unfinished draft"].waitForExistence(timeout: 10))
        app.staticTexts["Unfinished draft"].firstMatch.tap()
        XCTAssertTrue(app.textViews["essay-body"].waitForExistence(timeout: 5))
        XCTAssertTrue((app.textViews["essay-body"].value as? String ?? "").contains("steady rise"))
    }

    func testHistorySearchAndPartFilter() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch()
        for (part, name) in [("A", "Reading club"), ("B", "Online learning")] {
            XCTAssertTrue(app.buttons["new-part-\(part)"].waitForExistence(timeout: 10))
            app.buttons["new-part-\(part)"].tap()
            let title = app.textFields["task-title"]
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            title.tap(); title.typeText(name)
            app.buttons["finish-editing"].tap()
        }
        app.tabBars.buttons["历史"].tap()
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
}
