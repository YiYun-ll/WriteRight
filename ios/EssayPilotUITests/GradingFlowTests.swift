import XCTest

final class GradingFlowTests: XCTestCase {
    func testSubmitAndInspectAllReportViews() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch()
        let profile = app.tabBars.buttons["我的"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        if !app.buttons["login-link"].waitForExistence(timeout: 3) { profile.tap() }
        XCTAssertTrue(app.buttons["login-link"].waitForExistence(timeout: 5))
        app.buttons["login-link"].tap()
        let email = app.textFields["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap(); email.typeText("a@example.com")
        app.buttons["auth-send"].tap()
        app.textFields["auth-code"].tap(); app.textFields["auth-code"].typeText("123456")
        app.buttons["auth-verify"].tap()

        app.tabBars.buttons["练习"].tap()
        XCTAssertTrue(app.buttons["new-part-A"].waitForExistence(timeout: 5))
        app.buttons["new-part-A"].tap()
        app.textFields["task-title"].tap(); app.textFields["task-title"].typeText("Book club")
        app.textFields["task-prompt"].tap(); app.textFields["task-prompt"].typeText("Explain why books are useful.")
        app.buttons["收起键盘"].tap()
        app.buttons["confirm-task"].tap()
        let body = app.textViews["essay-body"]
        body.tap(); body.typeText("I has a book. It is useful.")
        app.buttons["submit-grading"].tap()

        let recent = app.buttons["recent-report"]
        XCTAssertTrue(recent.waitForExistence(timeout: 10))
        recent.tap()
        XCTAssertTrue(app.staticTexts["AI 模拟估分，不代替正式阅卷。"].waitForExistence(timeout: 5))
        let overview = XCTAttachment(screenshot: app.screenshot())
        overview.name = "P5 report overview"; overview.lifetime = .keepAlways
        add(overview)
        app.buttons["逐句"].tap()
        XCTAssertTrue(app.staticTexts["I have a book."].waitForExistence(timeout: 5))
        app.buttons["report-detail"].tap(); app.buttons["简洁"].tap()
        let conciseReport = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); conciseReport.name = "report-reading-concise"; conciseReport.lifetime = .keepAlways; add(conciseReport)
        app.buttons["report-detail"].tap(); app.buttons["详细"].tap()
        app.buttons["修改稿"].tap()
        XCTAssertTrue(app.buttons["表达增强"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["rewrite-translation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["rewrite-highlights"].exists || app.staticTexts["重点句，慢慢读"].exists)
        let rewritePage = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); rewritePage.name = "rewrite-bilingual-emphasis"; rewritePage.lifetime = .keepAlways; add(rewritePage)
        app.buttons["rewrite-toggle-translation"].tap()
        XCTAssertFalse(app.staticTexts["rewrite-translation"].exists)
        app.buttons["rewrite-toggle-translation"].tap()
        app.buttons["表达增强"].tap()
        XCTAssertTrue(app.staticTexts["rewrite-translation"].exists)
        app.buttons["复盘"].tap()
        XCTAssertTrue(app.staticTexts["下一次练习"].waitForExistence(timeout: 5))
        let keep = app.buttons["keep-expression"].firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5))
        keep.tap()
        XCTAssertEqual(keep.label, "已收藏")
        XCTAssertFalse(keep.isEnabled)
        app.buttons["close-report"].tap()
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        recent.tap(); app.buttons["report-section-review"].tap()
        XCTAssertEqual(app.buttons["keep-expression"].firstMatch.label, "已收藏")
        app.buttons["close-report"].tap()
        let reportUndo = app.buttons["undo-removal"]
        app.tabBars.buttons["我的"].tap(); app.buttons["profile-reports"].tap()
        let reportSearch = app.searchFields["搜索题目或点评"]
        XCTAssertTrue(reportSearch.waitForExistence(timeout: 5)); reportSearch.tap(); reportSearch.typeText("Book club\n")
        app.buttons["Close"].tap()
        let shelfRow = app.buttons["report-row"].firstMatch
        XCTAssertTrue(shelfRow.waitForExistence(timeout: 5))
        app.buttons["report-select"].tap(); app.buttons["report-batch-delete"].tap(); app.buttons["report-batch-delete"].tap()
        XCTAssertTrue(reportUndo.waitForExistence(timeout: 3)); reportUndo.tap()
        XCTAssertTrue(shelfRow.waitForExistence(timeout: 3))
        let reportShelf = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); reportShelf.name = "report-shelf-search-selection"; reportShelf.lifetime = .keepAlways; add(reportShelf)
        app.tabBars.buttons["练习"].tap()
        recent.swipeLeft(); app.buttons["delete-report"].tap()
        XCTAssertTrue(reportUndo.waitForExistence(timeout: 3))
        XCTAssertFalse(recent.exists)
        let reportUndoBar = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); reportUndoBar.name = "recent-report-undo-bar"; reportUndoBar.lifetime = .keepAlways; add(reportUndoBar)
        reportUndo.tap()
        XCTAssertTrue(recent.waitForExistence(timeout: 3))
        recent.swipeLeft(); app.buttons["delete-report"].tap()
        XCTAssertTrue(reportUndo.waitForExistence(timeout: 3))
        let reportUndoGone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: reportUndo)
        wait(for: [reportUndoGone], timeout: 10)
        XCTAssertFalse(recent.exists)

        app.tabBars.buttons["首页"].tap()
        let corner = app.buttons["home-open-favorites"]
        for _ in 0..<10 where !corner.isHittable { app.swipeUp() }
        XCTAssertTrue(corner.waitForExistence(timeout: 5))
        let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); home.name = "home-reading-corner"; home.lifetime = .keepAlways; add(home)
        corner.tap()
        let favorite = app.staticTexts["be useful for"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.swipeLeft(); app.buttons["删除"].firstMatch.tap()
        let undo = app.buttons["undo-removal"]
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        XCTAssertFalse(favorite.exists)
        let undoBar = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); undoBar.name = "favorite-undo-bar"; undoBar.lifetime = .keepAlways; add(undoBar)
        undo.tap()
        XCTAssertTrue(favorite.waitForExistence(timeout: 3))

        app.tabBars.buttons["练习"].tap()
        app.buttons["practice-history"].tap()
        let row = app.staticTexts["Book club"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft(); app.buttons["删除"].firstMatch.tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        undo.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.swipeLeft(); app.buttons["删除"].firstMatch.tap()
        XCTAssertTrue(undo.waitForExistence(timeout: 3))
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: undo)
        wait(for: [gone], timeout: 10)
        XCTAssertTrue(app.staticTexts["还没有练习"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Book club"].exists)
    }
}
