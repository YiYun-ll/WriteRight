import Foundation

enum ScanImageStoreError: Error { case invalidPath }

struct ScanImageStore: Sendable {
    let root: URL

    func url(_ relativePath: String) -> URL? {
        guard relativePath.hasSuffix(".jpg"),
              UUID(uuidString: String(relativePath.dropLast(4))) != nil,
              !relativePath.contains("/") else { return nil }
        return root.appendingPathComponent(relativePath)
    }

    func save(data: Data, id: UUID) throws -> String {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let name = "\(id.uuidString).jpg"
        #if os(iOS)
        try data.write(to: root.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: root.appendingPathComponent(name), options: [.atomic])
        #endif
        return name
    }

    func remove(_ relativePath: String) throws {
        guard let url = url(relativePath) else { throw ScanImageStoreError.invalidPath }
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
