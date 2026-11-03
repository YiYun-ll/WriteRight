import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ProfileImageStore {
    let root: URL
    func url(owner: String) -> URL { root.appendingPathComponent("profile-images/\(owner).jpg") }
    func load(owner: String) -> Data? { try? Data(contentsOf: url(owner: owner)) }
    func save(_ data: Data, owner: String) throws -> Data {
        let normalized = try Self.normalized(data, size: 640)
        let target = url(owner: owner)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try normalized.write(to: target, options: [.atomic, .completeFileProtection])
        return normalized
    }
    func erase(owner: String) throws {
        let target = url(owner: owner)
        if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
    }
    /// ImageIO downsamples before decoding and re-encodes without location/EXIF metadata.
    static func normalized(_ data: Data, size: Int) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: size,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return output as Data
    }
}
