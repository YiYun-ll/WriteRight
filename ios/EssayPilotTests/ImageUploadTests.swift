import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#if canImport(EssayPilot)
@testable import EssayPilot
#endif

final class ImageUploadTests: XCTestCase {
    func testOversizedImageEitherFitsBudgetOrReturnsActionableError() throws {
        let width = 2600, height = 2600
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        var seed: UInt32 = 7
        for i in pixels.indices where i % 4 != 3 {
            seed = seed &* 1664525 &+ 1013904223
            pixels[i] = UInt8(truncatingIfNeeded: seed >> 24)
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let bytes = NSMutableData()
        let destination = CGImageDestinationCreateWithData(bytes, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let original = bytes as Data
        XCTAssertGreaterThan(original.count, ImageUploadEncoder.maximumBytes)
        let before = ContentFingerprint.hash(original.base64EncodedString())
        let upload: Data
        do { upload = try ImageUploadEncoder.jpeg(from: original) }
        catch ImageUploadError.tooLarge {
            // Extremely noisy photos may be refused rather than made unreadably small.
            XCTAssertEqual(ContentFingerprint.hash(original.base64EncodedString()), before)
            return
        }
        XCTAssertLessThanOrEqual(upload.count, ImageUploadEncoder.maximumBytes)
        XCTAssertLessThan(("data:image/jpeg;base64," + upload.base64EncodedString()).count, 2_000_000)
        XCTAssertEqual(ContentFingerprint.hash(original.base64EncodedString()), before)
        let decoded = CGImageSourceCreateWithData(upload as CFData, nil)!
        XCTAssertEqual(CGImageSourceGetType(decoded) as String?, UTType.jpeg.identifier)
        let properties = CGImageSourceCopyPropertiesAtIndex(decoded, 0, nil) as! [CFString: Any]
        XCTAssertLessThanOrEqual(properties[kCGImagePropertyPixelWidth] as! Int, 2400)
        XCTAssertLessThanOrEqual(properties[kCGImagePropertyPixelHeight] as! Int, 2400)
    }

    func testTransparentScanGetsAWhiteJPEGBackground() throws {
        let canvas = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        canvas.clear(CGRect(x: 0, y: 0, width: 64, height: 64))
        canvas.setFillColor(CGColor(gray: 0, alpha: 1)); canvas.fill(CGRect(x: 24, y: 24, width: 16, height: 16))
        let bytes = NSMutableData()
        let destination = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, canvas.makeImage()!, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let original = bytes as Data
        let upload = try ImageUploadEncoder.jpeg(from: original)
        XCTAssertLessThanOrEqual(upload.count, ImageUploadEncoder.maximumBytes)
        let source = CGImageSourceCreateWithData(upload as CFData, nil)!
        XCTAssertEqual(CGImageSourceGetType(source) as String?, UTType.jpeg.identifier)
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let check = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 256,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        check.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
        let pixel = check.data!.assumingMemoryBound(to: UInt8.self)
        XCTAssertGreaterThan(pixel[0], 245); XCTAssertGreaterThan(pixel[1], 245); XCTAssertGreaterThan(pixel[2], 245)
        XCTAssertEqual(bytes as Data, original)
    }

    func testInvalidSourceIsRejectedBeforeUpload() {
        XCTAssertThrowsError(try ImageUploadEncoder.jpeg(from: Data()))
        XCTAssertThrowsError(try ImageUploadEncoder.jpeg(from: Data("not an image".utf8)))
    }
}
