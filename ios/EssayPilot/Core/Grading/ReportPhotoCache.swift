import Foundation

/// Report originals kept per account so a report can be read offline. Files are named by their
/// content hash and re-checked on every read, so a damaged or swapped file is simply fetched again.
struct ReportPhotoCache {
    let root: URL

    func data(for source: PhotoSource) -> Data? {
        guard let url = url(for: source), let data = try? Data(contentsOf: url),
              ContentFingerprint.hash(data) == source.checksum.lowercased() else { return nil }
        return data
    }
    func store(_ data: Data, for source: PhotoSource) throws {
        guard let url = url(for: source), ContentFingerprint.hash(data) == source.checksum.lowercased() else { return }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    private func url(for source: PhotoSource) -> URL? {
        let name = source.checksum.lowercased()
        guard name.count == 64, name.allSatisfy(\.isHexDigit) else { return nil }
        return root.appendingPathComponent(name + ".jpg")
    }
}
