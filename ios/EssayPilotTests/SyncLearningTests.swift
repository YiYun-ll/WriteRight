import XCTest
@testable import EssayPilot

@MainActor final class SyncLearningTests: XCTestCase {
    func testTwoDevicesKeepBothEditsAndDoNotResurrectADelete() async throws {
        let server = SyncDirectory()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let auth = SyncTestAuth()
        let first = AppModel(authService: auth, storeRoot: root.appendingPathComponent("a"), gradingService: UITestGradingService(), syncTransport: server)
        let second = AppModel(authService: auth, storeRoot: root.appendingPathComponent("b"), gradingService: UITestGradingService(), syncTransport: server)
        let firstLogin = await first.verifyCode(email: "a@example.com", code: "123456")
        let secondLogin = await second.verifyCode(email: "a@example.com", code: "123456")
        XCTAssertTrue(firstLogin)
        XCTAssertTrue(secondLogin)
        var draft = try XCTUnwrap(first.createDraft(part: .a))
        draft.body = "Shared starting draft."
        draft.task.prompt = "Invite a friend."
        try first.repository?.save(draft)
        await first.syncNow()
        await second.syncNow()
        XCTAssertEqual(second.drafts.first?.body, "Shared starting draft.")

        var left = try XCTUnwrap(first.drafts.first)
        var right = try XCTUnwrap(second.drafts.first)
        left.body = "Edited on the first device."
        right.body = "Edited on the second device."
        try first.repository?.save(left)
        try second.repository?.save(right)
        await first.syncNow()
        await second.syncNow()
        await first.syncNow()
        let bodies = Set(first.drafts.map(\.body)).union(second.drafts.map(\.body))
        XCTAssertTrue(bodies.contains("Edited on the first device."))
        XCTAssertTrue(bodies.contains("Edited on the second device."))
        XCTAssertEqual(first.syncState, "已同步")

        let original = try XCTUnwrap(first.drafts.first { $0.conflictOf == nil })
        first.delete(original)
        await first.syncNow()
        await second.syncNow()
        XCTAssertFalse(second.drafts.contains { $0.id == original.id })
        XCTAssertFalse(first.drafts.contains { $0.id == original.id })
    }

    func testFavoriteDedupStatsAndComparison() throws {
        let repository = try SwiftDataWritingRepository(inMemory: true)
        let first = FavoriteDocument.make(expression: "Be useful for", meaning: "对……有用", usage: "Reading is useful for learning.", reportID: UUID(), sentence: "It is useful.")
        let second = FavoriteDocument.make(expression: "be   useful for", meaning: "", usage: "", reportID: UUID(), sentence: "Books are useful.")
        try repository.keepFavorite(first)
        try repository.keepFavorite(second)
        let saved = try repository.favorites()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved[0].sources.count, 2)
        XCTAssertEqual(saved[0].meaning, "对……有用")

        let task = WritingTaskDocument.empty(part: .b)
        let older = SubmissionDocument(id: UUID(), draftID: UUID(), task: task, originalText: "First attempt.", wordCount: 2, contentHash: "a", sentences: [], submittedAt: .now.addingTimeInterval(-100))
        let newer = SubmissionDocument(id: UUID(), draftID: UUID(), task: task, originalText: "Second attempt.", wordCount: 2, contentHash: "b", sentences: [], submittedAt: .now)
        let lone = report(submission: older, part: .b, score: 8, rubric: "B1")
        XCTAssertTrue(PracticeAnalytics.series(PracticeAnalytics.points(submissions: [older], reports: [lone]), part: .b).isEmpty)
        let later = report(submission: newer, part: .b, score: 11, rubric: "B2")
        let points = PracticeAnalytics.points(submissions: [older, newer], reports: [lone, later])
        XCTAssertEqual(PracticeAnalytics.series(points, part: .b).count, 2)
        XCTAssertFalse(PracticeAnalytics.comparable(points))
        let comparison = try XCTUnwrap(PracticeAnalytics.comparison(taskID: task.id, submissions: [older, newer], reports: [lone, later]))
        XCTAssertFalse(comparison.comparable)
        XCTAssertEqual(comparison.left.originalText, "First attempt.")
        XCTAssertEqual(comparison.right.originalText, "Second attempt.")
        XCTAssertNil(PracticeAnalytics.comparison(taskID: UUID(), submissions: [older], reports: [lone]))
    }

    func testPhotoComparisonUsesQuestionFingerprintAndSkipsIncompleteReports() throws {
        var task = WritingTaskDocument.empty(part: .a); task.photoFingerprint = "same-question"
        var other = WritingTaskDocument.empty(part: .a); other.photoFingerprint = "same-question"
        let first = SubmissionDocument(id: UUID(), draftID: UUID(), task: task, originalText: "", wordCount: 0, contentHash: "a", sentences: [], submittedAt: .now.addingTimeInterval(-20))
        let second = SubmissionDocument(id: UUID(), draftID: UUID(), task: other, originalText: "", wordCount: 0, contentHash: "b", sentences: [], submittedAt: .now.addingTimeInterval(-10))
        let pending = SubmissionDocument(id: UUID(), draftID: UUID(), task: other, originalText: "", wordCount: 0, contentHash: "c", sentences: [], submittedAt: .now)
        let reports = [report(submission: first, part: .a, score: 6, rubric: "PHOTO"), report(submission: second, part: .a, score: 8, rubric: "PHOTO")]
        let pair = try XCTUnwrap(PracticeAnalytics.comparison(taskID: task.id, submissions: [first, second, pending], reports: reports))
        XCTAssertEqual(pair.left.id, first.id); XCTAssertEqual(pair.right.id, second.id)
        XCTAssertTrue(pair.comparable)
        var point = try XCTUnwrap(PracticeAnalytics.points(submissions: [first], reports: reports).first)
        point.estimatedSource = true
        XCTAssertNil(PracticeAnalytics.errorsPerHundredWords(point))
    }

    func testFavoriteStateTracksSuccessfulSaveDedupAndRemoval() throws {
        let repository = try SwiftDataWritingRepository(inMemory: true)
        let app = AppModel(repository: repository)
        let submission = SubmissionDocument(id: UUID(), draftID: UUID(), task: .empty(part: .a), originalText: "Example.", wordCount: 1, contentHash: "x", sentences: [], submittedAt: .now)
        let result = report(submission: submission, part: .a, score: 7, rubric: "A")
        let expression = ReviewExpression(expression: "Be useful for", meaning: "对……有用", usage: "Reading is useful for learning.")
        XCTAssertFalse(app.isKept(expression: expression.expression))
        app.keep(expression: expression, report: result)
        XCTAssertTrue(app.isKept(expression: "be   useful for"))
        app.keep(expression: expression, report: result)
        XCTAssertEqual(app.favorites.count, 1)
        app.deleteFavorite(id: try XCTUnwrap(app.favorites.first?.id))
        XCTAssertFalse(app.isKept(expression: expression.expression))
    }

    func testDeleteAccountFailureKeepsLocalDrafts() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let auth = SyncTestAuth(failDelete: true)
        let model = AppModel(authService: auth, storeRoot: root, gradingService: UITestGradingService(), syncTransport: SyncDirectory())
        let loggedIn = await model.verifyCode(email: "a@example.com", code: "123456")
        XCTAssertTrue(loggedIn)
        XCTAssertNotNil(model.createDraft(part: .a))
        await model.deleteAccount()
        XCTAssertEqual(model.drafts.count, 1)
        XCTAssertNotNil(model.errorMessage)
    }

    private func report(submission: SubmissionDocument, part: WritingPart, score: Double, rubric: String) -> GradingReportDocument {
        let payload = GradingReportPayload(
            schemaVersion: "1", part: part, gradingMode: "full",
            score: .init(value: score, max: part.maximumScore, band: "中等", range: nil, confidence: "medium"),
            wordCount: 20, rubricVersion: rubric, promptVersion: "P", modelID: "synthetic",
            overallComment: "ok", dimensions: [], taskChecks: [.init(pointID: "p1", status: "passed", reason: "covered", evidenceSentenceIDs: [])],
            corrections: [.init(sentenceID: "s1", original: "x", minimalCorrected: "y", category: "语法", severity: "required", impact: "medium", reasonZH: "改", optionalUpgrade: nil)],
            rewrites: .init(minimal: "y", enhanced: "y"),
            review: .init(topIssues: [], expressions: [], practiceAdvice: "再写一次")
        )
        return GradingReportDocument(id: UUID(), jobID: UUID(), submissionID: submission.id, part: part, report: payload, sentences: [], createdAt: submission.submittedAt)
    }
}

private actor SyncTestAuth: AuthService {
    private let failDelete: Bool
    init(failDelete: Bool = false) { self.failDelete = failDelete }
    private var session: AccountSession?
    nonisolated var sessionChanges: AsyncStream<AccountSession?> { AsyncStream { _ in } }
    func currentSession() async throws -> AccountSession? { session }
    func requestCode(email: String) async throws {}
    func verifyCode(email: String, code: String) async throws -> AccountSession {
        let session = AccountSession(userID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!, email: email)
        self.session = session
        return session
    }
    func updateEmail(_ email: String) async throws {}
    func signOut() async throws { session = nil }
    func deleteAccount() async throws {
        if failDelete { throw AuthServiceError.invalidSession }
        session = nil
    }
}
