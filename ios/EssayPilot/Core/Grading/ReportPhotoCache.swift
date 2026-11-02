import Foundation

/// Report originals kept per account so a report can be read offline. Files are named by their
/// content hash and re-checked on every read, so a damaged or swapped file is simply fetched again.
struct ReportPhotoCache {
    struct Usage: Equatable { var bytes: Int; var files: Int }
    let root: URL

    func data(for source: PhotoSource) -> Data? {
        guard let url = url(for: source), let data = try? Data(contentsOf: url),
              ContentFingerprint.hash(data) == source.checksum.lowercased() else { return nil }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }
    func store(_ data: Data, for source: PhotoSource) throws {
        guard let url = url(for: source), ContentFingerprint.hash(data) == source.checksum.lowercased() else { return }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func usage() throws -> Usage {
        guard FileManager.default.fileExists(atPath: root.path) else { return Usage(bytes: 0, files: 0) }
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles])
        return try files.reduce(into: Usage(bytes: 0, files: 0)) { usage, url in
            usage.bytes += try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            usage.files += 1
        }
    }
    @discardableResult func trim(limitBytes: Int) throws -> Int {
        guard limitBytes >= 0, FileManager.default.fileExists(atPath: root.path) else { return 0 }
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
        let entries = try files.map { url in
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            return (url: url, bytes: values.fileSize ?? 0, modified: values.contentModificationDate ?? .distantPast)
        }.sorted { $0.modified < $1.modified }
        var total = entries.reduce(0) { $0 + $1.bytes }
        var removed = 0
        for entry in entries where total > limitBytes {
            try FileManager.default.removeItem(at: entry.url)
            total -= entry.bytes; removed += entry.bytes
        }
        return removed
    }
    @discardableResult func removeAll() throws -> Int {
        let current = try usage()
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
        return current.bytes
    }
    private func url(for source: PhotoSource) -> URL? {
        let name = source.checksum.lowercased()
        guard name.count == 64, name.allSatisfy(\.isHexDigit) else { return nil }
        return root.appendingPathComponent(name + ".jpg")
    }
}
