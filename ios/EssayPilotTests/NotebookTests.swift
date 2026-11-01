import XCTest
import SwiftData
@testable import EssayPilot

@MainActor final class NotebookTests: XCTestCase {
    func testShareLinkParsingRejectsExecutableSchemesAndCredentials() {
        XCTAssertEqual(NotebookLink.url("分享： https://v.douyin.com/abc/ ，复制打开")?.host, "v.douyin.com")
        XCTAssertEqual(NotebookLink.source(URL(string: "https://xhslink.com/o/abc")!), "小红书")
        XCTAssertNil(NotebookLink.url("javascript:alert(1)"))
        XCTAssertNil(NotebookLink.url("http://example.com"))
        XCTAssertNil(NotebookLink.url("https://name:password@example.com"))
        XCTAssertNil(NotebookLink.url("https://127.0.0.1/a"))
        XCTAssertEqual(NotebookLink.source(URL(string: "https://douyin.com.evil.example/a")!), "douyin.com.evil.example")
    }

    func testRecordsSurviveReopenAndAreAccountScoped() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("writing.store")
        let entry = NotebookEntry(title: "给自己留十分钟")
        do { let repo = try SwiftDataWritingRepository(ownerKey: "A", storeURL: url); try repo.saveNotebook(entry) }
        let reopened = try SwiftDataWritingRepository(ownerKey: "A", storeURL: url)
        XCTAssertEqual(try reopened.notebookChanges().first?.entry, entry)
        let other = try SwiftDataWritingRepository(ownerKey: "B", storeURL: url)
        XCTAssertTrue(try other.notebookChanges().isEmpty)
        XCTAssertThrowsError(try other.saveNotebook(entry))
    }

    func testSyncCompletionConflictCopiesAndDeletionTombstone() async throws {
        let a = try SwiftDataWritingRepository(inMemory: true)
        let b = try SwiftDataWritingRepository(inMemory: true)
        let owner = UUID(); let cloud = SyncDirectory()
        var entry = NotebookEntry(title: "慢慢写一段")
        try a.saveNotebook(entry)
        _ = try await AccountSynchronizer.sync(userID: owner, repository: a, transport: cloud)
        _ = try await AccountSynchronizer.sync(userID: owner, repository: b, transport: cloud)
        XCTAssertEqual(try b.notebookChanges().first?.entry.title, entry.title)
        var remote = entry; remote.note = "A的新想法"
        try a.saveNotebook(remote)
        _ = try await AccountSynchronizer.sync(userID: owner, repository: a, transport: cloud)
        entry.note = "B的离线想法"; try b.saveNotebook(entry)
        let result = try await AccountSynchronizer.sync(userID: owner, repository: b, transport: cloud)
        XCTAssertEqual(result.conflicts, 1)
        XCTAssertTrue(try b.notebookChanges().contains { $0.entry.note == "B的离线想法" })
        XCTAssertTrue(try b.notebookChanges().contains { $0.entry.note == "A的新想法" })
        remote.deletedAt = .now; try a.saveNotebook(remote)
        _ = try await AccountSynchronizer.sync(userID: owner, repository: a, transport: cloud)
        _ = try await AccountSynchronizer.sync(userID: owner, repository: b, transport: cloud)
        XCTAssertNotNil(try b.notebookChanges().first { $0.entry.id == remote.id }?.entry.deletedAt)
    }

    func testRetriedPushWithSameContentDoesNotCreateACopy() async throws {
        let first = try SwiftDataWritingRepository(inMemory: true)
        let retry = try SwiftDataWritingRepository(inMemory: true)
        let owner = UUID(); let cloud = SyncDirectory()
        let entry = NotebookEntry(title: "回信要写得具体")
        try first.saveNotebook(entry)
        _ = try await AccountSynchronizer.sync(userID: owner, repository: first, transport: cloud)
        // Same content still dirty at base revision 0, as if the first response never arrived.
        try retry.saveNotebook(entry)
        let result = try await AccountSynchronizer.sync(userID: owner, repository: retry, transport: cloud)
        XCTAssertEqual(result.conflicts, 0)
        let changes = try retry.notebookChanges()
        XCTAssertEqual(changes.map(\.entry.title), ["回信要写得具体"])
        XCTAssertEqual(changes.first?.dirty, false)
    }

    func testLateSyncAcknowledgementDoesNotClearNewerEdit() throws {
        let repo = try SwiftDataWritingRepository(inMemory: true)
        let sent = NotebookEntry(title: "原来的安排")
        try repo.saveNotebook(sent)
        var edited = sent; edited.note = "发送期间补写的内容"; try repo.saveNotebook(edited)
        try repo.acknowledgeNotebook(sent, revision: 1, deleted: false)
        XCTAssertTrue(try XCTUnwrap(repo.notebookChanges().first).dirty)
        XCTAssertEqual(try repo.notebookChanges().first?.entry.note, edited.note)
    }

    func testUndoAfterSyncedDeletionCreatesNewRecord() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(storeRoot: root)
        let entry = NotebookEntry(title: "明天再看一眼")
        XCTAssertTrue(model.saveNotebook(entry))
        var deleted = entry; deleted.deletedAt = .now
        XCTAssertTrue(model.saveNotebook(deleted))
        try model.repository?.acknowledgeNotebook(deleted, revision: 2, deleted: true)
        XCTAssertTrue(model.restoreNotebook(entry))
        XCTAssertEqual(model.notebook.count, 1)
        XCTAssertNotEqual(model.notebook.first?.id, entry.id)
        let changes = try XCTUnwrap(model.repository).notebookChanges()
        XCTAssertNotNil(changes.first { $0.entry.id == entry.id }?.entry.deletedAt)
        XCTAssertTrue(changes.first { $0.entry.id != entry.id }?.dirty == true)
    }

    func testV3StoreUpgradesWithoutLosingDraft() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("writing.store")
        let draft = DraftDocument(id: UUID(), task: .empty(part: .a), body: "A page worth keeping.", source: "typed", transcriptionConfirmed: true, createdAt: .now, updatedAt: .now)
        do {
            let schema = Schema(WritingSchemaV3.models)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            let context = ModelContext(container)
            context.insert(LocalWritingDraft(document: draft, ownerKey: "local", payload: try JSONEncoder().encode(draft)))
            try context.save()
        }
        let repo = try SwiftDataWritingRepository(storeURL: url)
        XCTAssertEqual(try repo.drafts().first?.body, draft.body)
        try repo.saveNotebook(NotebookEntry(title: "新的一页"))
        XCTAssertEqual(try repo.notebookChanges().count, 1)
    }
}
