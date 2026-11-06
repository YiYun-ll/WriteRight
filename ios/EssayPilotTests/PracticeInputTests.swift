import XCTest
@testable import EssayPilot

@MainActor final class PracticeInputTests: XCTestCase {
    private func setup(_ root: URL) async -> AppModel {
        let app = AppModel(authService: UITestAuthService(), storeRoot: root, gradingService: UITestGradingService())
        _ = await app.verifyCode(email: "mixed@example.com", code: "123456")
        return app
    }
    func testBothMixedDirectionsPreserveSnapshotsAndClientAcceptsReports() async throws {
        for textTask in [true, false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let app = await setup(root); let model = PhotoPracticeModel(app: app)
            let image = try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "I has a book. It is useful.")))
            if textTask {
                model.taskMode = .text; model.taskText = "Write an invitation to Alex."
                await model.add([image], role: .essay)
            } else {
                await model.add([image], role: .task)
                model.answerMode = .text; model.essayText = "I has a book. It is useful."
            }
            await model.submit()
            XCTAssertNotNil(model.jobID)
            let submission = try XCTUnwrap(app.submissions.first)
            XCTAssertEqual(submission.textInputs?.task, textTask ? model.taskText : "")
            XCTAssertEqual(submission.textInputs?.essay, textTask ? "" : model.essayText)
            XCTAssertEqual(submission.originalText, "")
            XCTAssertNotNil(app.gradingReports.first)
            XCTAssertEqual(app.gradingReports.first?.report.photoReview?.textSources, submission.textInputs)
            XCTAssertTrue(app.continuingDrafts.isEmpty)
            XCTAssertEqual(app.reusablePracticeTasks.count, 1)
            app.hideReusableTask(try XCTUnwrap(app.reusablePracticeTasks.first))
            XCTAssertTrue(app.reusablePracticeTasks.isEmpty)
            XCTAssertEqual(app.gradingReports.count, 1)
            XCTAssertEqual(app.submissions.count, 1)
            model.cancel()
        }
    }
    func testModeSwitchKeepsBothAlternativesButSubmitsOnlySelectedSource() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = await setup(root); let model = PhotoPracticeModel(app: app)
        let image = try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "Photo content")))
        await model.add([image], role: .task); await model.add([image], role: .essay)
        model.taskMode = .text; model.taskText = "Typed task"; model.answerMode = .text; model.essayText = "Typed answer."
        let saved = try XCTUnwrap(model.saveDraft())
        XCTAssertEqual(saved.pages?.count, 1); XCTAssertEqual(saved.task.sourcePages?.count, 1)
        XCTAssertTrue(saved.activePracticeDraft.pages?.isEmpty == true)
        XCTAssertTrue(saved.activePracticeDraft.task.sourcePages?.isEmpty == true)
        let reopened = PhotoPracticeModel(app: app, draft: saved)
        XCTAssertEqual(reopened.taskText, "Typed task"); XCTAssertEqual(reopened.essayText, "Typed answer.")
        reopened.taskMode = .photos
        XCTAssertEqual(reopened.taskPages.count, 1)
        XCTAssertEqual(reopened.taskText, "Typed task")
        model.cancel(); reopened.cancel()
    }
    func testRemovingLastPhotoPersistsEmptyStateInsteadOfRestoringOldPage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = await setup(root); let model = PhotoPracticeModel(app: app)
        await model.add([try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "Original")))], role: .essay)
        model.remove(try XCTUnwrap(model.essayPages.first), role: .essay)
        XCTAssertTrue(app.drafts.first?.pages?.isEmpty == true)
        XCTAssertTrue(app.continuingDrafts.isEmpty)
        model.cancel()
    }
    func testTranslationReferenceIsPartOfClientPhotoFingerprint() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = await setup(root); let model = PhotoPracticeModel(app: app)
        model.part = .translation; model.referenceTranslation = "仅供对照。"
        let image = try XCTUnwrap(UIImage(data: ScanSampleImage.jpeg(text: "Synthetic")))
        await model.add([image], role: .task); await model.add([image], role: .essay)
        await model.submit()
        XCTAssertEqual(app.gradingReports.first?.report.score.value, 14.75)
        XCTAssertNotNil(model.jobID)
        model.cancel()
    }
}
