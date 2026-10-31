import XCTest
#if canImport(EssayPilot)
@testable import EssayPilot
#endif

final class ScanImageStoreTests: XCTestCase {
    func testDiscardRemovesOnlyTheUncommittedPageAndIsIdempotent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ScanImageStore(root: root)
        let retained = try store.save(data: Data([1, 2, 3]), id: UUID())
        let discarded = try store.save(data: Data([4, 5, 6]), id: UUID())
        try store.remove(discarded)
        try store.remove(discarded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.url(discarded)!.path))
        XCTAssertEqual(try Data(contentsOf: store.url(retained)!), Data([1, 2, 3]))
    }
    func testDiscardRejectsTraversalAndAmbiguousNames() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: parent) }
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let outside = parent.appendingPathComponent("outside.jpg")
        try Data([7, 8, 9]).write(to: outside)
        let store = ScanImageStore(root: parent.appendingPathComponent("owner"))
        for path in ["../outside.jpg", outside.path, "\(UUID().uuidString).other.jpg", "not-a-uuid.jpg"] {
            XCTAssertThrowsError(try store.remove(path))
        }
        XCTAssertEqual(try Data(contentsOf: outside), Data([7, 8, 9]))
    }
    func testDiscardUnlinksSymlinkWithoutTouchingTarget() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let target = root.appendingPathComponent("retained.txt")
        try Data([11, 12]).write(to: target)
        let store = ScanImageStore(root: root)
        let name = "\(UUID().uuidString).jpg"
        try FileManager.default.createSymbolicLink(at: store.url(name)!, withDestinationURL: target)
        try store.remove(name)
        XCTAssertEqual(try Data(contentsOf: target), Data([11, 12]))
    }
}
