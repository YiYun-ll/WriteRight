import XCTest
@testable import EssayPilot

@MainActor final class GradingTests: XCTestCase {
    private var directory: URL!
    private var auth: GradingTestAuth!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        auth = GradingTestAuth()
    }

    override func tearDown() {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil; auth = nil
    }

    func testSubmissionUsesDurableIDAndCachesImmutableReport() async throws {
        let model = AppModel(authService: auth, storeRoot: directory, gradingService: UITestGradingService())
        let loggedIn = await model.verifyCode(email: "a@example.com", code: "123456")
        XCTAssertTrue(loggedIn)
        let draft = try XCTUnwrap(model.createDraft(part: .a))
        var edited = draft
        edited.task.prompt = "Explain why books are useful."
        edited.task.confirmedAt = .now
        edited.body = "I has a book. It is useful."
        try model.repository?.save(edited)

        let submitted = await model.submitGrading(edited)
        let job = try XCTUnwrap(submitted)
        XCTAssertEqual(job.id, job.idemKey)
        XCTAssertEqual(job.status, .completed)
        XCTAssertEqual(model.submissions.count, 1)
        XCTAssertEqual(model.gradingReports.count, 1)
        XCTAssertEqual(model.submissions.first?.originalText, edited.body)

        let report = try XCTUnwrap(model.gradingReports.first)
        var changed = edited; changed.body = "Later edits must not replace the snapshot."
        try model.repository?.save(changed)
        XCTAssertEqual(model.submissions.first?.originalText, edited.body)
        XCTAssertThrowsError(try model.repository?.saveGradingReport(.init(
            id: report.id, jobID: report.jobID, submissionID: report.submissionID,
            part: report.part, report: report.report, sentences: [], createdAt: report.createdAt
        )))

        let reopened = AppModel(authService: auth, storeRoot: directory, gradingService: UITestGradingService())
        let restored = await reopened.verifyCode(email: "a@example.com", code: "123456")
        XCTAssertTrue(restored)
        XCTAssertEqual(reopened.gradingReports.first?.report.rewrites.minimal, report.report.rewrites.minimal)
        XCTAssertEqual(reopened.gradingReports.first?.report.sentenceReviews?.items.map(\.original), report.sentences.map(\.original))
        XCTAssertEqual(reopened.gradingReports.first?.report.sentenceReviews?.items.first?.reasonZH, report.report.sentenceReviews?.items.first?.reasonZH)
        XCTAssertEqual(reopened.gradingReports.first?.sentences.map(\.startUTF16), report.sentences.map(\.startUTF16))
    }

    func testUnresolvedRecognitionCannotBeSubmitted() async throws {
        let model = AppModel(authService: auth, storeRoot: directory, gradingService: UITestGradingService())
        let loggedIn = await model.verifyCode(email: "a@example.com", code: "123456")
        XCTAssertTrue(loggedIn)
        let draft = try XCTUnwrap(model.createDraft(part: .a))
        var edited = draft
        edited.body = "Dear Alex, [待确认] you."
        edited.transcriptionConfirmed = true
        edited.source = "ocr"
        let blocked = await model.submitGrading(edited)
        XCTAssertNil(blocked)
        XCTAssertTrue(model.submissions.isEmpty)
        edited.body = "Dear Alex, I invite you."
        edited.transcriptionConfirmed = false
        let unconfirmed = await model.submitGrading(edited)
        XCTAssertNil(unconfirmed)
        XCTAssertTrue(model.submissions.isEmpty)
    }
}

private actor GradingTestAuth: AuthService {
    private var session: AccountSession?
    nonisolated var sessionChanges: AsyncStream<AccountSession?> { AsyncStream { _ in } }
    func currentSession() async throws -> AccountSession? { session }
    func requestCode(email: String) async throws {}
    func verifyCode(email: String, code: String) async throws -> AccountSession {
        let session = AccountSession(
            userID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!, email: email
        )
        self.session = session
        return session
    }
    func updateEmail(_ email: String) async throws {}
    func signOut() async throws { session = nil }
    func deleteAccount() async throws { session = nil }
}
