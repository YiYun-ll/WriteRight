import XCTest

/// Opt in by creating /tmp/writeright-acceptance.json with a LOCAL url and public key.
/// Requires a running local worker and a seeded synthetic image in Simulator Photos.
final class LiveAcceptanceTests: XCTestCase {
    private func json(_ url: String) throws -> [String: Any] {
        let done = expectation(description: "Local acceptance request")
        var result: Result<Data, Error>?
        URLSession.shared.dataTask(with: URL(string: url)!) { data, _, error in
            result = error.map { .failure($0) } ?? .success(data ?? Data())
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 15)
        return try JSONSerialization.jsonObject(with: XCTUnwrap(result).get()) as? [String: Any] ?? [:]
    }

    func testRealAlbumOCRAndModelReport() throws {
        let file = URL(fileURLWithPath: "/tmp/writeright-acceptance.json")
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("Local live acceptance is opt in; default UI tests use fixtures.")
        }
        let config = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: String]
        guard config["url"] == "http://127.0.0.1:54321" else { throw XCTSkip("Only local acceptance is allowed") }
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-store", UUID().uuidString, "-ui-test-live", "-appearance", "light"]
        app.launchEnvironment["WRITERIGHT_SUPABASE_URL"] = config["url"]
        app.launchEnvironment["WRITERIGHT_SUPABASE_PUBLISHABLE_KEY"] = config["key"]
        app.launch()
        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.buttons["login-link"].waitForExistence(timeout: 10))
        app.buttons["login-link"].tap()
        let email = "acceptance-\(UUID().uuidString.lowercased())@example.com"
        app.textFields["auth-email"].tap(); app.textFields["auth-email"].typeText(email)
        app.buttons["auth-send"].tap()
        var code: String?
        for _ in 0..<15 {
            let list = try json("http://127.0.0.1:54324/api/v1/messages")
            for message in list["messages"] as? [[String: Any]] ?? [] {
                guard let id = message["ID"] as? String else { continue }
                let body = try json("http://127.0.0.1:54324/api/v1/message/" + id)
                let text = (body["Text"] as? String ?? "") + (body["HTML"] as? String ?? "")
                guard text.contains(email) || String(describing: body["To"]).contains(email) else { continue }
                let regex = try NSRegularExpression(pattern: "(?<![0-9])[0-9]{6}(?![0-9])")
                if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range, in: text) { code = String(text[range]); break }
            }
            if code != nil { break }
            RunLoop.current.run(until: Date().addingTimeInterval(1))
        }
        let otp = try XCTUnwrap(code, "Real local OTP must arrive")
        app.textFields["auth-code"].tap(); app.textFields["auth-code"].typeText(otp)
        app.buttons["auth-verify"].tap()
        XCTAssertTrue(app.buttons[email].waitForExistence(timeout: 10))
        app.tabBars.buttons["练习"].tap()
        app.buttons["new-part-A"].tap()
        app.textFields["task-title"].tap(); app.textFields["task-title"].typeText("Reading club invitation")
        app.textFields["task-prompt"].tap()
        app.textFields["task-prompt"].typeText("Write an email inviting Alex to a reading club. Give time and place, describe the activity and ask for a reply. Sign Li Ming.")
        app.buttons["收起键盘"].tap(); app.buttons["confirm-task"].tap()
        app.buttons["open-scan"].tap(); app.buttons["拍照作文"].tap()
        app.buttons["scan-album"].tap()
        let photo = app.images.matching(NSPredicate(format: "label CONTAINS[c] 'Photo' OR label CONTAINS '照片' ")).firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 10), app.debugDescription)
        photo.tap()
        let addPhoto = app.buttons["Add"].exists ? app.buttons["Add"] : app.buttons["添加"]
        if addPhoto.waitForExistence(timeout: 3) { addPhoto.tap() }
        let transcript = app.textViews["scan-transcript-0"]
        XCTAssertTrue(transcript.waitForExistence(timeout: 40), app.debugDescription)
        XCTAssertTrue((transcript.value as? String ?? "").isEmpty)
        app.buttons["ai-transcribe-0"].tap()
        app.buttons["发送这一页并转录"].tap()
        let candidate = app.textViews["ai-transcript-candidate"]
        XCTAssertTrue(candidate.waitForExistence(timeout: 120))
        let text = candidate.value as? String ?? ""
        XCTAssertTrue(text.contains("Dear Alex"))
        XCTAssertTrue(text.contains("I has prepared"), "AI must preserve the synthetic student's error")
        let checked = app.switches["ai-transcript-checked"]
        for _ in 0..<5 where !checked.isHittable { app.swipeUp() }
        checked.tap()
        app.buttons["adopt-ai-transcript"].tap()
        let scan = XCTAttachment(screenshot: app.screenshot()); scan.name = "Live album AI reading"; scan.lifetime = .keepAlways; add(scan)
        app.buttons["confirm-transcript"].tap()
        XCTAssertTrue(app.textViews["essay-body"].waitForExistence(timeout: 5))
        app.buttons["submit-grading"].tap()
        let report = app.buttons["recent-report"].firstMatch
        XCTAssertTrue(report.waitForExistence(timeout: 240), app.debugDescription)
        report.tap()
        XCTAssertTrue(app.staticTexts["AI 模拟估分，不代替正式阅卷。"].waitForExistence(timeout: 10))
        let graded = XCTAttachment(screenshot: app.screenshot()); graded.name = "Live DeepSeek report"; graded.lifetime = .keepAlways; add(graded)
        app.buttons["逐句"].tap()
        app.buttons["修改稿"].tap()
        XCTAssertTrue(app.buttons["表达增强"].waitForExistence(timeout: 5))
        app.buttons["复盘"].tap()
        XCTAssertTrue(app.staticTexts["下一次练习"].waitForExistence(timeout: 5))
        app.buttons["close-report"].tap()
        app.terminate(); app.launch()
        app.tabBars.buttons["练习"].tap()
        XCTAssertTrue(app.buttons["recent-report"].firstMatch.waitForExistence(timeout: 10))
    }
}
