import XCTest
@testable import EssayPilot

final class WritingTextTests: XCTestCase {
    func testReferenceWordCount() {
        let cases: [(String, Int)] = [
            ("I am a student.", 4), ("I don't know.", 3), ("well-known solution", 2),
            ("The volume grew by 15%.", 5), ("  I\n\n am  here. ", 3), ("...!?", 0),
            ("2022 15% 3.14", 3), ("中文 don't isn’t well‑known", 3)
        ]
        for (text, count) in cases { XCTAssertEqual(WordCounter.count(text), count, text) }
    }

    func testSentenceRangesKeepDuplicateTextAndUnicode() {
        let text = "😀 I am here. I am here.\n\nThe rate is 3.5%. Mr. Smith agrees."
        let sentences = SentenceSegmenter.sentences(in: text)
        XCTAssertGreaterThan(sentences.count, 2)
        XCTAssertEqual(Set(sentences.map(\.id)).count, sentences.count)
        for sentence in sentences {
            XCTAssertEqual((text as NSString).substring(with: NSRange(location: sentence.startUTF16, length: sentence.lengthUTF16)), sentence.original)
        }
        XCTAssertNotEqual(sentences[0].startUTF16, sentences[1].startUTF16)
        XCTAssertTrue(sentences.contains { $0.original.contains("3.5%") })
        XCTAssertTrue(sentences.contains { $0.paragraphIndex > 0 })
    }

    func testFingerprintsPreserveOriginalWhitespace() {
        XCTAssertNotEqual(ContentFingerprint.hash("I am here."), ContentFingerprint.hash("I am here. "))
        XCTAssertEqual(ContentFingerprint.hash("unchanged"), ContentFingerprint.hash("unchanged"))
    }
}

@MainActor final class WritingPersistenceTests: XCTestCase {
    private func draft(part: WritingPart = .a) -> DraftDocument {
        var task = WritingTaskDocument.empty(part: part)
        task.prompt = "Write a letter inviting a friend to the reading club."
        task.confirmedAt = .now
        return .init(id: UUID(), task: task, body: "I would like to invite you.", source: "typed", transcriptionConfirmed: true, createdAt: .now, updatedAt: .now)
    }

    func testDraftSurvivesReopeningDiskStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("writing.store")
        let document = draft()
        var first: SwiftDataWritingRepository? = try .init(storeURL: url)
        try first?.save(document)
        first = nil
        let reopened = try SwiftDataWritingRepository(storeURL: url)
        XCTAssertEqual(try reopened.drafts(), [document])
    }

    func testSubmissionCannotBeOverwrittenByDraftEdits() throws {
        let repository = try SwiftDataWritingRepository(inMemory: true)
        var document = draft(part: .b)
        let original = document.body
        let submission = SubmissionDocument(id: UUID(), draftID: document.id, task: document.task, originalText: original, wordCount: document.wordCount, contentHash: ContentFingerprint.hash(original), sentences: SentenceSegmenter.sentences(in: original), submittedAt: .now)
        try repository.save(document); try repository.saveSubmission(submission)
        document.body = "A different later draft."
        try repository.save(document)
        XCTAssertEqual(try repository.submissions().first?.originalText, original)
        let overwritten = SubmissionDocument(id: submission.id, draftID: document.id, task: document.task, originalText: document.body, wordCount: document.wordCount, contentHash: ContentFingerprint.hash(document.body), sentences: [], submittedAt: submission.submittedAt)
        XCTAssertThrowsError(try repository.saveSubmission(overwritten))
        try repository.saveSubmission(submission)
        XCTAssertEqual(try repository.submissions().count, 1)
    }

    func testOwnerIsolationRejectsReusingAnExistingID() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("writing.store")
        let first = try SwiftDataWritingRepository(ownerKey: "first", storeURL: url)
        let second = try SwiftDataWritingRepository(ownerKey: "second", storeURL: url)
        let document = draft()
        try first.save(document)
        XCTAssertTrue(try second.drafts().isEmpty)
        XCTAssertThrowsError(try second.save(document))
        XCTAssertEqual(try first.drafts().first?.body, document.body)
    }

    func testEditorInvalidatesConfirmedTaskWhenRequirementsChange() throws {
        let repository = try SwiftDataWritingRepository(inMemory: true)
        let document = draft()
        try repository.save(document)
        let editor = EssayEditorModel(document: document, repository: repository, didSave: {})
        XCTAssertTrue(editor.taskConfirmed)
        editor.requirements = "Give a date\nExplain the purpose"
        XCTAssertTrue(editor.save())
        XCTAssertFalse(editor.taskConfirmed)
        XCTAssertEqual(try repository.drafts().first?.task.revision, 2)
        editor.confirmTask()
        XCTAssertTrue(editor.taskConfirmed)
        XCTAssertEqual(try repository.drafts().first?.task.requirements.count, 2)
    }

    func testDeletedDraftRemainsAbsentAfterRepositoryReload() throws {
        let repository = try SwiftDataWritingRepository(inMemory: true)
        let document = draft()
        try repository.save(document)
        try repository.deleteDraft(id: document.id)
        XCTAssertTrue(try repository.drafts().isEmpty)
    }

    func testNewAttemptKeepsTaskIdentityAndDoesNotReuseTheOldBody() throws {
        let repository = try SwiftDataWritingRepository(inMemory: true)
        let original = draft()
        try repository.save(original)
        let app = AppModel(repository: repository)
        let next = try XCTUnwrap(app.createDraft(part: original.task.part, task: original.task))
        XCTAssertNotEqual(next.id, original.id)
        XCTAssertEqual(next.task, original.task)
        XCTAssertTrue(next.body.isEmpty)
        XCTAssertEqual(try repository.drafts().first(where: { $0.id == original.id })?.body, original.body)
    }

    func testFailedSaveKeepsEditsAvailableForRetry() throws {
        let store = try SwiftDataWritingRepository(inMemory: true)
        let original = draft()
        try store.save(original)
        let repository = FailingWritingRepository(store: store)
        let editor = EssayEditorModel(document: original, repository: repository, didSave: {})
        let edited = "A new paragraph.\n\nAll of my latest edits stay here."
        editor.body = edited
        repository.failWrites = true
        XCTAssertFalse(editor.save())
        XCTAssertNotNil(editor.saveError)
        XCTAssertEqual(editor.body, edited)
        XCTAssertEqual(try store.drafts().first?.body, original.body)
        repository.failWrites = false
        XCTAssertTrue(editor.save())
        XCTAssertNil(editor.saveError)
        XCTAssertEqual(try store.drafts().first?.body, edited)
    }
}

@MainActor private final class FailingWritingRepository: WritingRepository {
    let store: SwiftDataWritingRepository
    var failWrites = false
    init(store: SwiftDataWritingRepository) { self.store = store }
    func drafts() throws -> [DraftDocument] { try store.drafts() }
    func submissions() throws -> [SubmissionDocument] { try store.submissions() }
    func save(_ draft: DraftDocument) throws {
        if failWrites { throw LocalStoreError.unavailable }
        try store.save(draft)
    }
    func saveSubmission(_ submission: SubmissionDocument) throws { try store.saveSubmission(submission) }
    func deleteDraft(id: UUID) throws { try store.deleteDraft(id: id) }
    func gradingJobs() throws -> [GradingJobDocument] { try store.gradingJobs() }
    func gradingReports() throws -> [GradingReportDocument] { try store.gradingReports() }
    func saveGradingJob(_ job: GradingJobDocument) throws { try store.saveGradingJob(job) }
    func saveGradingReport(_ report: GradingReportDocument) throws { try store.saveGradingReport(report) }
    func exportData() throws -> Data { try store.exportData() }
}
