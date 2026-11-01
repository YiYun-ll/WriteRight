import XCTest

final class NotebookFlowTests: XCTestCase {
    @MainActor func testSavedLinkHandsOffToSystemBrowser() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString]
        app.launch(); app.tabBars.buttons["记录"].tap()
        let addButton = app.buttons["notebook-add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 8)); addButton.tap()
        let title = app.textFields["notebook-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("An idea to revisit")
        app.buttons["notebook-link-expand"].tap()
        let link = app.textFields["notebook-link"]
        link.tap(); link.typeText("https://www.xiaohongshu.com/")
        app.buttons["notebook-save"].tap()
        let open = app.buttons["notebook-open-link"]
        XCTAssertTrue(open.waitForExistence(timeout: 5)); open.tap()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 10))
        Thread.sleep(forTimeInterval: 1.0) // Let the app switch finish before capturing Safari.
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "notebook-link-browser"; shot.lifetime = .keepAlways; add(shot)
        app.activate()
        XCTAssertTrue(app.staticTexts["An idea to revisit"].waitForExistence(timeout: 5))
    }

    @MainActor func testRecordEditingLinkCompletionUndoAndRestart() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch(); app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(app.buttons["notebook-add"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["notebook-paste"].exists)
        app.buttons["notebook-add"].tap()
        let title = app.textFields["notebook-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap(); title.typeText("Leave ten quiet minutes")
        app.buttons["notebook-link-expand"].tap()
        let link = app.textFields["notebook-link"]
        link.tap(); link.typeText("https://xhslink.com/o/example")
        app.buttons["notebook-save"].tap()
        XCTAssertTrue(app.staticTexts["Leave ten quiet minutes"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["notebook-open-link"].exists)
        let sheet = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); sheet.name = "notebook-light"; sheet.lifetime = .keepAlways; add(sheet)
        app.terminate(); app.launch(); app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(app.staticTexts["Leave ten quiet minutes"].waitForExistence(timeout: 8))
        app.buttons["notebook-complete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["notebook-response"].waitForExistence(timeout: 5))
        app.buttons["notebook-filter"].tap(); app.buttons["已完成"].tap()
        XCTAssertTrue(app.staticTexts["Leave ten quiet minutes"].waitForExistence(timeout: 5))
        app.buttons["notebook-menu"].firstMatch.tap(); app.buttons["收起这条记录"].tap()
        XCTAssertTrue(app.buttons["notebook-undo"].waitForExistence(timeout: 5)); app.buttons["notebook-undo"].tap()
        XCTAssertTrue(app.staticTexts["Leave ten quiet minutes"].waitForExistence(timeout: 5))
        app.tabBars.buttons["练习"].tap(); app.buttons["practice-history"].tap()
        XCTAssertTrue(app.staticTexts["还没有练习"].waitForExistence(timeout: 5))
    }

    @MainActor func testLinksAreShelvedBySourceIncludingBilibiliAndWeChat() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch(); app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(app.buttons["notebook-add"].waitForExistence(timeout: 8))
        for share in ["Essay structure https://b23.tv/AbC123x", "Reading list https://mp.weixin.qq.com/s/Xy12AbC", "Another clip https://www.bilibili.com/video/BV1xx411c7mD"] {
            app.buttons["notebook-add"].tap()
            let kind = app.buttons["notebook-kind"]
            XCTAssertTrue(kind.waitForExistence(timeout: 5)); kind.tap(); app.buttons["灵感链接"].tap()
            let link = app.textFields["notebook-link"]
            XCTAssertTrue(link.waitForExistence(timeout: 5)); link.tap(); link.typeText(share)
            app.buttons["notebook-save"].tap()
            XCTAssertTrue(app.buttons["notebook-add"].waitForExistence(timeout: 5))
        }
        app.buttons["notebook-filter"].tap(); app.buttons["灵感链接"].tap()
        XCTAssertTrue(app.staticTexts["哔哩哔哩 · 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["微信公众号 · 1"].exists)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "notebook-link-sources"; shot.lifetime = .keepAlways; add(shot)
        app.buttons["notebook-source-微信公众号"].tap()
        XCTAssertTrue(app.staticTexts["Reading list"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Essay structure"].exists)
        app.buttons["notebook-source-all"].tap()
        XCTAssertTrue(app.staticTexts["Essay structure"].waitForExistence(timeout: 5))
    }

    @MainActor func testDarkLargeNotebookHasAccessibleControls() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch(); app.tabBars.buttons["记录"].tap()
        let add = app.buttons["notebook-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        let upper = app.navigationBars.firstMatch.frame.maxY + 8
        let lower = app.tabBars.firstMatch.frame.minY - 8
        for _ in 0..<10 {
            if add.frame.maxY <= lower && add.frame.minY >= upper && add.isHittable { break }
            let origin = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            let destination = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: add.frame.maxY > lower ? 0.53 : 0.77))
            origin.press(forDuration: 0.01, thenDragTo: destination)
        }
        XCTAssertGreaterThanOrEqual(add.frame.minY, upper)
        XCTAssertLessThanOrEqual(add.frame.maxY, lower)
        XCTAssertTrue(add.isHittable)
        XCTAssertLessThanOrEqual(add.frame.maxX, app.frame.maxX)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "notebook-dark-accessibility"; shot.lifetime = .keepAlways; self.add(shot)
    }
}
