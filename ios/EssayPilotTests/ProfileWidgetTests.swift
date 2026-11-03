import XCTest
import UIKit
import ImageIO
@testable import EssayPilot

private final class MemoryWidgetStore: WidgetSecondaryStore {
    var values: [String: Data] = [:]
    func save(_ data: Data, account: String) -> Bool { values[account] = data; return true }
    func load(account: String) -> Data? { values[account] }
    func delete(account: String) { values[account] = nil }
}

@MainActor final class ProfileWidgetTests: XCTestCase {
    private func fixture() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900)).jpegData(withCompressionQuality: 1) { context in
            UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
        }
    }
    func testAvatarDownsamplingPersistenceIsolationAndInvalidInput() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ProfileImageStore(root: root)
        let saved = try store.save(fixture(), owner: "A")
        let image = try XCTUnwrap(UIImage(data: saved))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 640)
        XCTAssertEqual(ProfileImageStore(root: root).load(owner: "A"), saved)
        XCTAssertNil(store.load(owner: "B"))
        XCTAssertThrowsError(try store.save(Data("invalid".utf8), owner: "A"))
        XCTAssertEqual(store.load(owner: "A"), saved)
        try store.erase(owner: "A"); XCTAssertNil(store.load(owner: "A"))
    }
    func testAvatarLateImportCannotWriteIntoAnotherAccount() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = AppModel(authService: UITestAuthService(), storeRoot: root)
        let data = fixture()
        await app.saveAvatar(data, owner: "guest")
        XCTAssertNotNil(app.avatarData)
        _ = await app.verifyCode(email: "avatar@example.com", code: "123456")
        XCTAssertNil(app.avatarData)
        await app.saveAvatar(data, owner: "guest"); XCTAssertNil(app.avatarData)
        await app.signOut(); XCTAssertNotNil(app.avatarData)
        app.removeAvatar(); XCTAssertNil(app.avatarData)
    }
    func testWidgetOptInFiltersCompletedDeletedAndOtherKindsAndClearsOnSignOut() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = AppModel(authService: UITestAuthService(), storeRoot: root)
        _ = await app.verifyCode(email: "widget@example.com", code: "123456")
        app.setWidgetRecordsEnabled(false)
        XCTAssertTrue(app.saveNotebook(NotebookEntry(title: "Visible task")))
        XCTAssertTrue(WidgetSnapshotStore.read().tasks.isEmpty)
        XCTAssertTrue(app.saveNotebook(NotebookEntry(title: "Completed", completed: true)))
        XCTAssertTrue(app.saveNotebook(NotebookEntry(kind: .note, title: "Private note")))
        XCTAssertTrue(app.saveNotebook(NotebookEntry(kind: .link, title: "Visible link", link: "https://example.com/page")))
        app.setWidgetRecordsEnabled(true)
        XCTAssertEqual(WidgetSnapshotStore.read().tasks.map(\.title), ["Visible task"])
        XCTAssertEqual(WidgetSnapshotStore.read().links.map(\.title), ["Visible link"])
        app.setWidgetRecordsEnabled(false)
        XCTAssertFalse(WidgetSnapshotStore.read().enabled)
        XCTAssertTrue(WidgetSnapshotStore.read().tasks.isEmpty)
        app.setWidgetRecordsEnabled(true)
        await app.signOut()
        XCTAssertFalse(WidgetSnapshotStore.read().enabled)
        _ = await app.verifyCode(email: "widget@example.com", code: "123456")
        app.setWidgetRecordsEnabled(false)
    }
    func testSavedPhotoAndRecordsRemainAfterGroupCopyIsRemoved() throws {
        let memory = MemoryWidgetStore()
        let previous = WidgetSnapshotStore.secondary
        WidgetSnapshotStore.secondary = memory
        defer {
            WidgetSnapshotStore.resetSharedCopies()
            WidgetSnapshotStore.secondary = previous
        }
        let photo = fixture()
        let snapshot = WidgetSnapshot(enabled: true, tasks: [WidgetRecord(id: UUID(), title: "Visible task", detail: "")], links: [])
        XCTAssertTrue(WidgetSnapshotStore.write(snapshot))
        try WidgetSnapshotStore.writeBackground(photo)
        WidgetSnapshotStore.eraseGroupCopies()
        XCTAssertEqual(WidgetSnapshotStore.read().tasks.map(\.title), ["Visible task"])
        XCTAssertEqual(WidgetSnapshotStore.readBackground(), photo)
        let decision = WidgetDisplay.resolve(theme: .midnight, content: .countdown, snapshot: WidgetSnapshotStore.read(), photo: WidgetSnapshotStore.readBackground())
        XCTAssertTrue(decision.usesPhoto)
        XCTAssertEqual(decision.records?.map(\.title), ["Visible task"])
    }
}
