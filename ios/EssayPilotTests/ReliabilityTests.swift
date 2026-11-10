import XCTest
@testable import EssayPilot

@MainActor final class ReliabilityTests: XCTestCase {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func draft(id: UUID = UUID(), body: String = "A saved page.") -> DraftDocument {
        var task = WritingTaskDocument.empty(part: .a); task.title = "Reading club"; task.prompt = "Invite a friend."
        return DraftDocument(id: id, task: task, body: body, source: "typed", transcriptionConfirmed: true, createdAt: .now, updatedAt: .now)
    }
    private func submission(_ draft: DraftDocument) -> SubmissionDocument {
        SubmissionDocument(id: UUID(), draftID: draft.id, task: draft.task, originalText: draft.body, wordCount: 3, contentHash: ContentFingerprint.hash(draft.body), sentences: [], submittedAt: .now)
    }
    private func report(_ submission: SubmissionDocument) -> GradingReportDocument {
        GradingReportDocument(
            id: UUID(), jobID: UUID(), submissionID: submission.id, part: .a,
            report: GradingReportPayload(
                schemaVersion: "1", part: .a, gradingMode: "full",
                score: .init(value: 8, max: 10, band: "良好", range: nil, confidence: "medium"),
                wordCount: 20, rubricVersion: "A", promptVersion: "P", modelID: "synthetic", overallComment: "清楚",
                dimensions: [], taskChecks: [], corrections: [], rewrites: .init(minimal: "y", enhanced: "y"),
                review: .init(topIssues: [], expressions: [], practiceAdvice: "再写一次")
            ), sentences: [], createdAt: .now
        )
    }

    func testBackupRoundTripRestoresContentAndOriginalImages() throws {
        let firstRoot = root(), secondRoot = root()
        defer { try? FileManager.default.removeItem(at: firstRoot); try? FileManager.default.removeItem(at: secondRoot) }
        let firstRepository = try SwiftDataWritingRepository(inMemory: true)
        let first = AppModel(repository: firstRepository, storeRoot: firstRoot)
        var document = draft()
        let image = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let pageID = UUID()
        let path = try first.scanImageStore().save(data: image, id: pageID)
        let page = ScanPageDocument(id: pageID, relativePath: path, rawText: "", correctedText: "", lines: [], confirmed: false, transcriptionSource: "direct_photo")
        document.pages = [page]; document.source = "photos"
        let submitted = submission(document), result = report(submitted)
        try firstRepository.save(document); try firstRepository.saveSubmission(submitted); try firstRepository.saveGradingReport(result)
        try firstRepository.saveNotebook(NotebookEntry(title: "一页"))
        first.refresh()
        let data = try Data(contentsOf: first.exportURL())
        let backup = try JSONDecoder().decode(WritingBackup.self, from: data)
        XCTAssertEqual(backup.schemaVersion, WritingBackup.currentVersion)
        XCTAssertEqual(backup.images.map(\.data), [image])

        let second = AppModel(repository: try SwiftDataWritingRepository(inMemory: true), storeRoot: secondRoot)
        let summary = try second.importBackup(data: data)
        XCTAssertEqual(summary.drafts, 1); XCTAssertEqual(summary.submissions, 1); XCTAssertEqual(summary.reports, 1); XCTAssertEqual(summary.images, 1)
        XCTAssertEqual(second.drafts.first?.pages?.first?.relativePath, path)
        XCTAssertEqual(second.submissions.first?.id, submitted.id)
        XCTAssertEqual(second.gradingReports.first?.id, result.id)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(second.scanImageStore().url(path))), image)
    }

    func testImportConflictCreatesANewDraftWithoutOverwritingCurrentWork() throws {
        let firstRoot = root(), secondRoot = root()
        defer { try? FileManager.default.removeItem(at: firstRoot); try? FileManager.default.removeItem(at: secondRoot) }
        let original = draft()
        let sourceRepository = try SwiftDataWritingRepository(inMemory: true)
        try sourceRepository.save(original)
        let source = AppModel(repository: sourceRepository, storeRoot: firstRoot)
        let submitted = submission(original), result = report(submitted)
        try sourceRepository.saveSubmission(submitted); try sourceRepository.saveGradingReport(result)
        let data = try Data(contentsOf: source.exportURL())

        let destinationRepository = try SwiftDataWritingRepository(inMemory: true)
        try destinationRepository.save(draft(id: original.id, body: "Keep this local edit."))
        let destination = AppModel(repository: destinationRepository, storeRoot: secondRoot)
        _ = try destination.importBackup(data: data)
        XCTAssertEqual(destination.drafts.count, 2)
        XCTAssertTrue(destination.drafts.contains { $0.body == "Keep this local edit." })
        let restoredDraft = try XCTUnwrap(destination.drafts.first { $0.body == original.body })
        XCTAssertNotEqual(restoredDraft.id, original.id)
        XCTAssertEqual(destination.submissions.first?.draftID, restoredDraft.id)
        XCTAssertEqual(destination.gradingReports.count, 1)
    }

    func testOfflineColdStartRestoresAccountAndAllowsCloudGradingRetry() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let auth = RestoreAuth()
        let online = AppModel(authService: auth, storeRoot: directory, gradingService: UITestGradingService())
        let loggedIn = await online.verifyCode(email: "offline@example.com", code: "123456")
        XCTAssertTrue(loggedIn)
        var document = try XCTUnwrap(online.createDraft(part: .a))
        document.task.prompt = "Invite a friend."
        document.task.confirmedAt = .now
        document.body = "I has a book. It is useful."
        try online.repository?.save(document)

        await auth.failRestore()
        let offline = AppModel(authService: auth, storeRoot: directory, gradingService: UITestGradingService())
        let observation = Task { await offline.observeAuth() }
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(offline.account?.userID, online.account?.userID)
        XCTAssertTrue(offline.isOfflineRestore)
        XCTAssertTrue(offline.canGrade)
        XCTAssertEqual(offline.drafts.map(\.id), [document.id])
        XCTAssertEqual(offline.syncState, "离线，本机可用")

        let submitted = await offline.submitGrading(document)
        let job = try XCTUnwrap(submitted)
        XCTAssertEqual(job.status, .completed)
        XCTAssertFalse(offline.isOfflineRestore)
        observation.cancel()
    }

    func testSuccessfulSyncClearsOfflineRestore() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let auth = RestoreAuth()
        let online = AppModel(authService: auth, storeRoot: directory, syncTransport: SyncDirectory())
        let loggedIn = await online.verifyCode(email: "offline@example.com", code: "123456")
        XCTAssertTrue(loggedIn)

        await auth.failRestore()
        let offline = AppModel(authService: auth, storeRoot: directory, syncTransport: SyncDirectory())
        let observation = Task { await offline.observeAuth() }
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(offline.isOfflineRestore)

        await offline.syncNow()
        XCTAssertFalse(offline.isOfflineRestore)
        XCTAssertNil(offline.authErrorMessage)
        XCTAssertEqual(offline.syncState, "已同步")
        observation.cancel()
    }

    func testSyncPullsEveryPageAndTracksPendingChanges() async throws {
        let cloud = SyncDirectory(), owner = UUID()
        for index in 0..<205 {
            var document = draft(body: "Page \(index)")
            document.id = UUID(); document.task.id = UUID()
            _ = try await cloud.push(userID: owner, op: SyncOperation(entityType: "draft", entityID: document.id, operation: "upsert", baseRevision: 0, payload: JSONEncoder().encode(document)))
        }
        let repository = try SwiftDataWritingRepository(inMemory: true)
        _ = try await AccountSynchronizer.sync(userID: owner, repository: repository, transport: PagedTransport(cloud: cloud))
        XCTAssertEqual(try repository.drafts().count, 205)

        let app = AppModel(repository: repository)
        try repository.save(draft())
        app.refresh()
        XCTAssertEqual(app.pendingSyncCount, 1)
        XCTAssertTrue(app.syncStatusDetail.contains("1 项待同步"))
    }

    func testPhotoEditIsSavedBeforeAnAccountCanChange() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let auth = RestoreAuth()
        let app = AppModel(authService: auth, storeRoot: directory, gradingService: UITestGradingService())
        let loggedIn = await app.verifyCode(email: "photo@example.com", code: "123456")
        XCTAssertTrue(loggedIn)
        let photos = PhotoPracticeModel(app: app)
        let image = try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "Keep this photo.")))
        await photos.add([image], role: .essay)
        XCTAssertEqual(app.drafts.count, 1)
        XCTAssertNotNil(app.drafts.first?.pages?.first)
        await app.signOut()
        XCTAssertTrue(app.drafts.isEmpty)
        let loggedBackIn = await app.verifyCode(email: "photo@example.com", code: "123456")
        XCTAssertTrue(loggedBackIn)
        XCTAssertEqual(app.drafts.count, 1)
    }

    func testFavoriteSourceUsesTheRelatedSentenceOrStaysEmpty() {
        let first = SentenceSpan(id: "s1", paragraphIndex: 0, original: "Books are useful.", startUTF16: 0, lengthUTF16: 17)
        let second = SentenceSpan(id: "s2", paragraphIndex: 0, original: "I like reading.", startUTF16: 18, lengthUTF16: 15)
        let correction = ReportCorrection(sentenceID: "s2", original: second.original, minimalCorrected: "Reading is useful for learning.", category: "语法", severity: "required", impact: "medium", reasonZH: "搭配", optionalUpgrade: nil)
        let base = report(submission(draft()))
        let payload = GradingReportPayload(
            schemaVersion: "1", part: .a, gradingMode: "full", score: base.report.score,
            wordCount: 20, rubricVersion: "A", promptVersion: "P", modelID: "synthetic", overallComment: "ok",
            dimensions: [], taskChecks: [], corrections: [correction], rewrites: base.report.rewrites, review: base.report.review
        )
        let document = GradingReportDocument(id: UUID(), jobID: UUID(), submissionID: base.submissionID, part: .a, report: payload, sentences: [first, second], createdAt: .now)
        let expression = ReviewExpression(expression: "be useful for", meaning: "有用", usage: "Reading is useful for learning.")
        XCTAssertEqual(FavoriteSourceLocator.sentence(for: expression, in: document), second.original)
        XCTAssertEqual(FavoriteSourceLocator.sentence(for: ReviewExpression(expression: "not present", meaning: "", usage: ""), in: document), "")
    }

    func testCacheTrimsOldestAndCanBeCleared() throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ReportPhotoCache(root: directory)
        for (index, size) in [10, 20, 30].enumerated() {
            let data = Data(repeating: UInt8(index + 1), count: size)
            let source = PhotoSource(role: "essay", page: 1, path: "\(index)", checksum: ContentFingerprint.hash(data))
            try cache.store(data, for: source)
            let url = directory.appendingPathComponent("\(source.checksum).jpg")
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: TimeInterval(index))], ofItemAtPath: url.path)
        }
        XCTAssertEqual(try cache.usage().files, 3)
        _ = try cache.trim(limitBytes: 40)
        XCTAssertEqual(try cache.usage(), ReportPhotoCache.Usage(bytes: 30, files: 1))
        XCTAssertEqual(try cache.removeAll(), 30)
        XCTAssertEqual(try cache.usage().files, 0)
    }

    func testFocusStartsAndEndsLiveActivityForCustomDurations() {
        let defaults = UserDefaults(suiteName: "focus-tests-\(UUID().uuidString)")!
        let activity = FocusActivitySpy()
        let cat = CompanionModel(owner: "a", defaults: defaults, now: .now, activity: activity)
        cat.startFocus(minutes: 60)
        XCTAssertEqual(activity.started?.minutes, 60)
        cat.startFocus(minutes: 120)
        XCTAssertEqual(activity.started?.minutes, 60, "an existing session is not replaced")
        cat.finishFocus(reports: 0)
        XCTAssertEqual(activity.finished, 1)
        cat.startFocus(minutes: 121)
        XCTAssertNotEqual(activity.started?.minutes, 121)
    }
}

actor RestoreAuth: AuthService {
    private var session: AccountSession?
    private var fails = false
    private let id = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
    nonisolated var sessionChanges: AsyncStream<AccountSession?> { AsyncStream { _ in } }
    func failRestore() { fails = true }
    func currentSession() async throws -> AccountSession? {
        if fails { throw URLError(.notConnectedToInternet) }
        return session
    }
    func requestCode(email: String) async throws {}
    func verifyCode(email: String, code: String) async throws -> AccountSession {
        let session = AccountSession(userID: id, email: email); self.session = session; fails = false
        return session
    }
    func updateEmail(_ email: String) async throws {}
    func signOut() async throws { session = nil }
    func deleteAccount() async throws { session = nil }
}

private final class PagedTransport: SyncTransport {
    let cloud: SyncDirectory
    init(cloud: SyncDirectory) { self.cloud = cloud }
    func push(userID: UUID, op: SyncOperation) async throws -> SyncPushResult { try await cloud.push(userID: userID, op: op) }
    func pull(userID: UUID, after: Int64) async throws -> [SyncChange] {
        Array(try await cloud.pull(userID: userID, after: after).prefix(200))
    }
    func mergeCompanion(userID: UUID, growth: CompanionGrowth) async throws -> CompanionGrowth {
        try await cloud.mergeCompanion(userID: userID, growth: growth)
    }
}

@MainActor private final class FocusActivitySpy: FocusActivityControlling {
    var started: (minutes: Int, start: Date, end: Date)?
    var finished = 0
    func start(name: String, startedAt: Date, endsAt: Date) {
        started = (Int(endsAt.timeIntervalSince(startedAt) / 60), startedAt, endsAt)
    }
    func finish(name: String, endsAt: Date) { finished += 1 }
}
