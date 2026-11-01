import XCTest

final class NotebookCreationTests: XCTestCase {
    @MainActor func testSingleEntryCreatesBodyOnlyNoteAndShareLinkAndSupportsEditing() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch(); app.tabBars.buttons["记录"].tap()
        let add = app.buttons["notebook-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 10)); XCTAssertFalse(app.buttons["notebook-paste"].exists)
        add.tap(); app.buttons["notebook-kind"].tap(); app.buttons["随手记"].tap()
        let note = app.textFields["notebook-note"]
        note.tap(); note.typeText("One small thought worth keeping.")
        app.buttons["notebook-save"].tap()
        XCTAssertTrue(app.staticTexts["One small thought worth keeping."].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["notebook-complete"].exists)
        app.buttons["notebook-edit"].firstMatch.tap()
        XCTAssertEqual(app.textFields["notebook-title"].value as? String, "One small thought worth keeping.")
        app.buttons["取消"].tap()
        app.buttons["notebook-filter"].tap(); app.buttons["灵感链接"].tap()
        add.tap()
        let link = app.textFields["notebook-link"]
        XCTAssertTrue(link.waitForExistence(timeout: 5)); link.tap(); link.typeText("A moment to revisit https://xhslink.com/o/example")
        app.buttons["notebook-save"].tap()
        XCTAssertTrue(app.staticTexts["A moment to revisit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["notebook-open-link"].exists)
        app.buttons["notebook-menu"].firstMatch.tap(); app.buttons["标记看过"].tap()
        XCTAssertTrue(app.staticTexts["已看过"].waitForExistence(timeout: 5))
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "notebook-seen-link"; shot.lifetime = .keepAlways; self.add(shot)
        app.buttons["notebook-filter"].tap(); app.buttons["手边"].tap()
        XCTAssertTrue(app.staticTexts["One small thought worth keeping."].firstMatch.waitForExistence(timeout: 5))
        app.terminate(); app.launch(); app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(app.staticTexts["One small thought worth keeping."].firstMatch.waitForExistence(timeout: 5))
    }
}
