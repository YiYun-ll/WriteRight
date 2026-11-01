import XCTest

final class DeskExperienceTests: XCTestCase {
    @MainActor func testDeskInteractionsCompanionAndProfileDestinations() {
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
        let pet = app.buttons["companion-pet"]
        XCTAssertTrue(pet.waitForExistence(timeout: 5)); pet.tap()
        let line = app.staticTexts["companion-line"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        let treat = app.buttons["companion-treat"]
        for _ in 0..<10 where !treat.isHittable { app.swipeUp() }
        treat.tap(); XCTAssertTrue(line.label.contains("小鱼干"))
        treat.tap(); XCTAssertTrue(line.label.contains("吃过"))
        app.buttons["companion-focus"].tap()
        app.buttons["10 分钟"].tap()
        XCTAssertTrue(app.buttons["companion-focus-end"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["companion-focus-timer"].exists)
        let desk = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); desk.name = "home-companion-focus"; desk.lifetime = .keepAlways; add(desk)
        app.buttons["companion-focus-end"].tap()
        XCTAssertTrue(app.buttons["companion-focus"].waitForExistence(timeout: 5))
        app.buttons["companion-growth"].tap()
        app.buttons["companion-rename"].tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "Mochi")
        app.buttons["就叫这个"].tap()
        XCTAssertTrue(app.staticTexts["Mochi"].waitForExistence(timeout: 5))
        let growth = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); growth.name = "home-companion-growth"; growth.lifetime = .keepAlways; add(growth)
        app.buttons["companion-growth-done"].tap()
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
        let reopenedPet = app.buttons["companion-pet"]
        XCTAssertTrue(reopenedPet.waitForExistence(timeout: 10))
        XCTAssertTrue(reopenedPet.label.hasPrefix("Mochi"))
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
