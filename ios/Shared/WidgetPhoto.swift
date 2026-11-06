import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// WidgetKit has a much smaller memory budget than the app. Decode one bounded bitmap,
/// including for legacy backgrounds; never let a full-resolution photo reach the view tree.
enum WidgetPhoto {
    static let maximumDimension = 600
    static let maximumEncodedBytes = 180_000

    static func image(_ data: Data) -> UIImage? {
        guard !data.isEmpty, data.count <= 30_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func normalized(_ data: Data) throws -> Data {
        guard let image = image(data)?.cgImage else { throw CocoaError(.fileReadCorruptFile) }
        for quality in [0.8, 0.6, 0.4] {
            let result = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(result, UTType.jpeg.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            if CGImageDestinationFinalize(destination), result.length <= maximumEncodedBytes { return result as Data }
        }
        throw CocoaError(.fileWriteOutOfSpace)
    }
}

enum WidgetStorageError: Error { case sharedAccessUnavailable }
