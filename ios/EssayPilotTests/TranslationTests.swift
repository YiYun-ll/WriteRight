import XCTest
@testable import EssayPilot

@MainActor final class TranslationTests: XCTestCase {
    func testTranslationDraftReferenceAndOriginalSurviveDiskReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("writing.store")
        var task = WritingTaskDocument.empty(part: .translation)
        task.prompt = UITestTranslationFixture.english
        task.referenceTranslation = "阅读让我们看见更广阔的世界。"
        task.confirmedAt = .now
        let draft = DraftDocument(id: UUID(), task: task, body: UITestTranslationFixture.student, source: "typed", transcriptionConfirmed: true, createdAt: .now, updatedAt: .now)
        var repository: SwiftDataWritingRepository? = try .init(storeURL: url)
        try repository?.save(draft)
        repository = nil
        let reopened = try SwiftDataWritingRepository(storeURL: url)
        XCTAssertEqual(try reopened.drafts(), [draft])
        XCTAssertEqual(draft.task.part.maximumScore, 15)
    }

    func testQuarterPointReportRoundTripAndChineseDoNotUseEnglishErrorDensity() throws {
        var task = WritingTaskDocument.empty(part: .translation)
        task.prompt = UITestTranslationFixture.english; task.confirmedAt = .now
        let report = try XCTUnwrap(UITestTranslationFixture.response(task: task, submissionID: UUID(), jobID: UUID()).report)
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(GradingReportDocument.self, from: data)
        XCTAssertEqual(report, decoded)
        XCTAssertEqual(decoded.report.score.value, 14.75)
        XCTAssertEqual(decoded.report.translationReview?.typoDeduction, 0.25)
        XCTAssertEqual(decoded.report.translationReview?.sentences.first?.student, "阅读打开大们。")
        let repository = try SwiftDataWritingRepository(inMemory: true)
        try repository.saveGradingReport(decoded)
        XCTAssertEqual(try repository.gradingReports().first, decoded)
    }

    func testReferenceChangeInvalidatesConfirmationAndSavesWithNewRevision() throws {
        let repository = try SwiftDataWritingRepository(inMemory: true)
        var task = WritingTaskDocument.empty(part: .translation)
        task.prompt = UITestTranslationFixture.english; task.confirmedAt = .now
        let draft = DraftDocument(id: UUID(), task: task, body: UITestTranslationFixture.student, source: "typed", transcriptionConfirmed: true, createdAt: .now, updatedAt: .now)
        let editor = EssayEditorModel(document: draft, repository: repository, didSave: {})
        editor.referenceTranslation = "仅供对照的参考译文"
        XCTAssertTrue(editor.save()); XCTAssertFalse(editor.taskConfirmed)
        XCTAssertEqual(editor.document.task.revision, 2)
        XCTAssertEqual(try repository.drafts().first?.task.referenceTranslation, editor.referenceTranslation)
    }

    func testOldWritingTaskWithoutTranslationFieldStillDecodes() throws {
        let task = WritingTaskDocument.empty(part: .a)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(task)) as? [String: Any])
        json.removeValue(forKey: "referenceTranslation")
        let decoded = try JSONDecoder().decode(WritingTaskDocument.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.part, .a); XCTAssertNil(decoded.referenceTranslation)
    }
}
