import XCTest
@testable import EssayPilot

@MainActor final class PhotoPracticeTests: XCTestCase {
    private func app(_ root: URL) async -> AppModel {
        let app = AppModel(authService: PhotoAuthStub(), storeRoot: root, gradingService: UITestGradingService())
        _ = await app.verifyCode(email: "photo@example.com", code: "123456")
        return app
    }
    func testPhotosSubmitDirectlyWithoutTranscriptOrTaskInventedFromEssay() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = await app(root); let model = PhotoPracticeModel(app: app)
        await model.add([try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "I has a book.")))], role: .essay)
        XCTAssertEqual(model.essayPages.first?.rawText, "")
        XCTAssertEqual(model.essayPages.first?.lines, [])
        XCTAssertTrue(model.canSubmit)
        await model.submit()
        XCTAssertNotNil(model.jobID)
        let submission = try XCTUnwrap(app.submissions.first)
        XCTAssertEqual(submission.originalText, ""); XCTAssertEqual(submission.sentences, [])
        XCTAssertEqual(submission.essayPages?.count, 1)
        XCTAssertNil(app.gradingReports.first?.report.score.value)
        XCTAssertEqual(app.gradingReports.first?.report.schemaVersion, "2.3.0")
        let page = try XCTUnwrap(app.drafts.first?.pages?.first)
        model.cancel()
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(app.scanImageStore().url(page.relativePath)).path))
        XCTAssertNotNil(page.uploadRelativePath)
    }
    func testSubmissionKeepsOrderedImagesAndRepeatedTapReusesSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = await app(root); let model = PhotoPracticeModel(app: app)
        let first = try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "First page.")))
        let second = try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "Second page.")))
        await model.add([first], role: .task); await model.add([first, second], role: .essay)
        let order = model.essayPages.map(\.id).reversed()
        model.move(model.essayPages[1], role: .essay, offset: -1)
        await model.submit(); let job = model.jobID
        XCTAssertEqual(app.submissions.first?.essayPages?.map(\.id), Array(order))
        XCTAssertNotNil(app.submissions.first?.task.photoFingerprint)
        XCTAssertNotNil(app.gradingReports.first?.report.score.value)
        await model.submit()
        XCTAssertEqual(model.jobID, job); XCTAssertEqual(app.submissions.count, 1)
    }
    func testPhotoDraftResumesWithOriginalImagesAndNoText() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = await app(root); let model = PhotoPracticeModel(app: app)
        await model.add([try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "Original.")))], role: .essay)
        let draft = try XCTUnwrap(model.saveDraft()); model.cancel()
        XCTAssertFalse(draft.isEmpty); XCTAssertEqual(draft.body, "")
        let resumed = PhotoPracticeModel(app: app, draft: draft)
        XCTAssertNotNil(resumed.image(try XCTUnwrap(resumed.essayPages.first)))
        XCTAssertEqual(resumed.essayPages.first?.rawText, "")
    }
    func testReportOriginalsOpenOfflineFromThisDeviceOrTheCache() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let online = await app(root); let model = PhotoPracticeModel(app: online)
        await model.add([try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "Task page.")))], role: .task)
        await model.add([try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "Essay page.")))], role: .essay)
        await model.submit(); model.cancel()
        let sources = try XCTUnwrap(online.gradingReports.first?.report.photoReview?.sources)
        let task = try XCTUnwrap(sources.first { $0.role == "task" }), essay = try XCTUnwrap(sources.first { $0.role == "essay" })
        // The essay's local upload is gone, so the first view downloads it and keeps a copy.
        let essayUpload = try XCTUnwrap(online.submissions.first?.essayPages?.first?.uploadRelativePath)
        try FileManager.default.removeItem(at: XCTUnwrap(online.scanImageStore().url(essayUpload)))
        let downloaded = try await online.gradingPhoto(essay)
        XCTAssertEqual(ContentFingerprint.hash(downloaded), essay.checksum)

        // A grading service that has nothing stands in for being offline.
        let offline = AppModel(authService: PhotoAuthStub(), storeRoot: root, gradingService: UITestGradingService())
        _ = await offline.verifyCode(email: "photo@example.com", code: "123456")
        let cachedEssay = try await offline.gradingPhoto(essay)
        XCTAssertEqual(cachedEssay, downloaded)
        let localTask = try await offline.gradingPhoto(task)
        XCTAssertEqual(ContentFingerprint.hash(localTask), task.checksum)

        // A damaged cached file is never shown as the original.
        let cacheFile = root.appendingPathComponent("JuGuang/accounts/11111111-1111-4111-8111-111111111111/report-photos/\(essay.checksum).jpg")
        try Data("not the photo".utf8).write(to: cacheFile)
        do { _ = try await offline.gradingPhoto(essay); XCTFail("Expected the damaged copy to be rejected") } catch {}
    }

    func testSwipedRowsHideFirstAndOnlyDeleteWhenTheUndoWindowCloses() async throws {
        let removal = PendingRemoval(window: .milliseconds(50))
        var deleted: [UUID] = []
        let first = UUID(), second = UUID()
        removal.remove(id: first, message: "已删除") { deleted.append(first) }
        XCTAssertTrue(removal.hides(first))
        removal.undo()
        XCTAssertFalse(removal.hides(first)); XCTAssertEqual(deleted, [])
        removal.remove(id: first, message: "已删除") { deleted.append(first) }
        removal.remove(id: second, message: "已删除") { deleted.append(second) }
        XCTAssertEqual(deleted, [first], "a second swipe settles the first")
        XCTAssertTrue(removal.hides(second))
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(deleted, [first, second]); XCTAssertNil(removal.item)
        removal.remove(id: first, message: "已删除") { deleted.append(first) }
        removal.finish()
        XCTAssertEqual(deleted, [first, second, first], "leaving the screen keeps the decision")
    }

    func testAccountSwitchBlocksPhotosFromSavingToAnotherAccount() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = await app(root); let model = PhotoPracticeModel(app: app)
        await model.add([try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "Original.")))], role: .essay)
        await app.signOut(); await model.submit()
        XCTAssertNil(model.jobID); XCTAssertTrue(app.drafts.isEmpty)
        model.cancel()
    }
}
private actor PhotoAuthStub: AuthService {
    nonisolated var sessionChanges: AsyncStream<AccountSession?> { AsyncStream { _ in } }
    func currentSession() async throws -> AccountSession? { nil }
    func requestCode(email: String) async throws {}
    func verifyCode(email: String, code: String) async throws -> AccountSession { .init(userID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!, email: email) }
    func updateEmail(_ email: String) async throws {}
    func signOut() async throws {}
    func deleteAccount() async throws {}
}
