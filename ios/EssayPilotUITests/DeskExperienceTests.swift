import XCTest

final class DeskExperienceTests: XCTestCase {
    @MainActor func testDeskInteractionsNoteAndProfileDestinations() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-appearance", "light"]
        app.launch()
        let lamp = app.buttons["home-lamp"]
        for _ in 0..<12 where !lamp.isHittable { app.swipeUp() }
        XCTAssertTrue(lamp.waitForExistence(timeout: 5))
        lamp.tap()
        XCTAssertEqual(lamp.value as? String, "已关")
        let tea = app.buttons["home-tea"]
        XCTAssertTrue(tea.waitForExistence(timeout: 5)); tea.tap()
        XCTAssertTrue(app.staticTexts["home-lamp-response"].label.contains("茶气"))
        let note = app.buttons["home-private-note"]
        for _ in 0..<20 where !note.isHittable { app.swipeUp() }
        XCTAssertTrue(note.waitForExistence(timeout: 5)); note.tap()
        let field = app.textFields["desk-note-text"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("One clear sentence today.")
        app.buttons["desk-note-done"].tap()
        let desk = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); desk.name = "home-desk-interactions"; desk.lifetime = .keepAlways; add(desk)
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.buttons["login-link"].waitForExistence(timeout: 5))
        let profile = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); profile.name = "profile-library-light"; profile.lifetime = .keepAlways; add(profile)
        app.buttons["profile-reports"].tap()
        XCTAssertTrue(app.staticTexts["还没有回信"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let help = app.buttons["profile-help"]
        for _ in 0..<6 where !help.isHittable { app.swipeUp() }
        XCTAssertTrue(help.waitForExistence(timeout: 5)); help.tap()
        XCTAssertTrue(app.buttons["怎样用照片批改？"].waitForExistence(timeout: 5))
        app.buttons["怎样用照片批改？"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        let about = app.buttons["profile-about"]
        for _ in 0..<3 where !about.isHittable { app.swipeUp() }
        about.tap()
        let leaf = app.buttons["留给翻到这里的你"]
        XCTAssertTrue(leaf.waitForExistence(timeout: 5)); leaf.tap()
        XCTAssertTrue(app.staticTexts["谢谢你愿意再写一次。愿这本小小的写作本，能在某个不容易的晚上，让你少一点孤单。"].waitForExistence(timeout: 5))
        let aboutPage = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); aboutPage.name = "profile-about-letter"; aboutPage.lifetime = .keepAlways; add(aboutPage)
        app.terminate(); app.launch()
        for _ in 0..<12 where !app.buttons["home-private-note"].isHittable { app.swipeUp() }
        app.buttons["home-private-note"].tap()
        XCTAssertEqual(app.textFields["desk-note-text"].value as? String, "One clear sentence today.")
        app.buttons["desk-note-clear"].tap()
        app.buttons["desk-note-done"].tap()
    }

    @MainActor func testProfileDarkLargeTextRemainsUsable() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-tab", "profile", "-appearance", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let favorites = app.buttons["profile-favorites"]
        for _ in 0..<5 where !favorites.isHittable { app.swipeUp() }
        XCTAssertTrue(favorites.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(favorites.frame.maxX, app.frame.maxX)
        let dark = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); dark.name = "profile-library-dark-accessibility"; dark.lifetime = .keepAlways; add(dark)
        favorites.tap()
        XCTAssertTrue(app.staticTexts["还没有收藏"].waitForExistence(timeout: 5))
    }
}
