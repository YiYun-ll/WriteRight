import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImageUploadError: Error { case invalidImage, tooLarge }

/// A separate upload copy. Neither the source bytes nor the saved OCR image is changed.
enum ImageUploadEncoder {
    // base64 + data URL prefix stays below the server's 2,000,000-character limit.
    static let maximumBytes = 1_400_000

    static func jpeg(from sourceData: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { throw ImageUploadError.invalidImage }
        let attempts: [(Int, Double)] = [(2400, 0.85), (2400, 0.72), (2000, 0.72), (1600, 0.72), (1600, 0.6)]
        for (edge, quality) in attempts {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: edge
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
                  thumbnail.width > 0, thumbnail.height > 0,
                  let canvas = CGContext(data: nil, width: thumbnail.width, height: thumbnail.height,
                                         bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                throw ImageUploadError.invalidImage
            }
            // JPEG has no alpha; transparent scans should keep a paper-white background.
            canvas.setFillColor(CGColor(gray: 1, alpha: 1))
            let rect = CGRect(x: 0, y: 0, width: thumbnail.width, height: thumbnail.height)
            canvas.fill(rect); canvas.draw(thumbnail, in: rect)
            guard let image = canvas.makeImage() else { throw ImageUploadError.invalidImage }
            let bytes = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw ImageUploadError.invalidImage
            }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw ImageUploadError.invalidImage }
            if bytes.length <= maximumBytes { return bytes as Data }
        }
        throw ImageUploadError.tooLarge
    }
}
