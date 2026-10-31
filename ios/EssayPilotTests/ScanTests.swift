import XCTest
@testable import EssayPilot

final class ScanContractTests: XCTestCase {
    func testLowConfidenceLineBecomesPlaceholderAndKeepsCandidate() {
        let line = OCRLineDocument(
            id: UUID(), text: "recieve", confidence: 0.2, alternatives: ["receive"],
            x: 0.1, y: 0.8, width: 0.4, height: 0.05
        )
        let normalized = OCRTranscript.normalizedLine(line)
        XCTAssertEqual(normalized.text, "[待确认]")
        XCTAssertEqual(normalized.alternatives, ["recieve", "receive"])
        XCTAssertTrue(OCRTranscript.containsUnresolved(OCRTranscript.joined([normalized])))
        let clear = OCRLineDocument(
            id: UUID(), text: "invite", confidence: 0.9, alternatives: [],
            x: 0.1, y: 0.2, width: 0.3, height: 0.05
        )
        XCTAssertEqual(OCRTranscript.normalizedLine(clear).text, "invite")
    }

    func testReadingOrderIsTopToBottomThenLeftToRight() {
        let lower = OCRLineDocument(id: UUID(), text: "second", confidence: 1, alternatives: [], x: 0.1, y: 0.2, width: 0.2, height: 0.05)
        let upperRight = OCRLineDocument(id: UUID(), text: "right", confidence: 1, alternatives: [], x: 0.6, y: 0.8, width: 0.2, height: 0.05)
        let upperLeft = OCRLineDocument(id: UUID(), text: "left", confidence: 1, alternatives: [], x: 0.1, y: 0.8, width: 0.2, height: 0.05)
        XCTAssertEqual(OCRTranscript.readingOrder([lower, upperRight, upperLeft]).map(\.text), ["left", "right", "second"])
    }

    func testImagePathsStayInsideTheOwnerFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanImageStore(root: root)
        let id = UUID()
        let name = try store.save(data: Data([0xFF, 0xD8, 0xFF]), id: id)
        XCTAssertEqual(store.url(name)?.lastPathComponent, "\(id.uuidString).jpg")
        XCTAssertNil(store.url("../secret.jpg"))
        XCTAssertNil(store.url("not-a-uuid.jpg"))
        XCTAssertNil(store.url("\(id.uuidString)/nested.jpg"))
        let user = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!
        XCTAssertEqual(
            ScanImageBackupPath.objectPath(userID: user, pageID: id),
            "\(user.uuidString.lowercased())/scans/\(id.uuidString.lowercased()).jpg"
        )
    }


}

@MainActor final class ScanEditorTests: XCTestCase {
    private func editor(part: WritingPart = .b) throws -> (EssayEditorModel, SwiftDataWritingRepository) {
        let repository = try SwiftDataWritingRepository(inMemory: true)
        var task = WritingTaskDocument.empty(part: part)
        task.prompt = "Describe the chart."
        task.confirmedAt = .now
        let document = DraftDocument(
            id: UUID(), task: task, body: "The chart shows a rise.", source: "typed",
            transcriptionConfirmed: true, createdAt: .now, updatedAt: .now
        )
        try repository.save(document)
        return (EssayEditorModel(document: document, repository: repository, didSave: {}), repository)
    }

    private func page(_ text: String, confirmed: Bool) -> ScanPageDocument {
        .init(id: UUID(), relativePath: "\(UUID().uuidString).jpg", rawText: text, correctedText: text, lines: [], confirmed: confirmed)
    }

    func testEssayScanReplacesBodyAndKeepsConfirmedTranscript() throws {
        let (editor, repository) = try editor()
        editor.useEssayScan([page("Dear Alex, I recieved your letter.", confirmed: true)], append: false)
        XCTAssertEqual(editor.body, "Dear Alex, I recieved your letter.")
        let saved = try XCTUnwrap(repository.drafts().first)
        XCTAssertEqual(saved.source, "ocr")
        XCTAssertTrue(saved.transcriptionConfirmed)
        XCTAssertEqual(saved.pages?.count, 1)
        XCTAssertEqual(saved.task.prompt, "Describe the chart.")
    }

    func testTaskPhotoWithoutParsedFactsDoesNotConfirmTheTask() throws {
        let (editor, repository) = try editor(part: .b)
        let before = try XCTUnwrap(repository.drafts().first?.task.revision)
        editor.useTaskScan([page("The graph shows visitors.", confirmed: true)], directions: "The graph shows visitors.", parsed: nil)
        let saved = try XCTUnwrap(repository.drafts().first)
        XCTAssertEqual(saved.task.prompt, "The graph shows visitors.")
        XCTAssertNil(saved.task.confirmedAt)
        XCTAssertFalse(editor.taskConfirmed)
        XCTAssertEqual(saved.task.revision, before + 1)
        XCTAssertEqual(saved.body, "The chart shows a rise.")
    }

    func testParsedTaskConfirmsChartFactsOnce() throws {
        let (editor, repository) = try editor(part: .b)
        let parsed = ParsedTaskDocument(
            part: .b, promptType: "chart", genre: "essay",
            requiredPoints: [.init(id: "p1", description: "Summarise the information.")],
            chartFacts: [.init(id: "f1", label: "cars", period: "2010", value: "20", unit: "%", confidence: "high", confirmedByUser: false)],
            wordRequirement: .init(target: 150, min: nil, max: nil, source: "default_guideline"),
            uncertainFields: []
        )
        editor.useTaskScan([page("Write about the chart.", confirmed: true)], directions: "Write about the chart.", parsed: parsed)
        let saved = try XCTUnwrap(repository.drafts().first)
        XCTAssertTrue(saved.task.isConfirmed)
        XCTAssertEqual(saved.task.chartFacts?.first?.confirmedByUser, true)
        XCTAssertEqual(saved.task.chartFacts?.first?.value, "20")
        XCTAssertEqual(saved.task.requirements.map(\.text), ["Summarise the information."])
        XCTAssertEqual(saved.task.revision, 2)
    }
}
