import Foundation
import UIKit

extension ScanImageStore {
    @MainActor static func normalized(_ image: UIImage, rotation: Bool = false) throws -> Data {
        guard image.size.width.isFinite, image.size.height.isFinite, image.size.width > 0, image.size.height > 0 else { throw ScanError.invalidImage }
        let ratio = min(1, 2400 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let target = rotation ? CGSize(width: size.height, height: size.width) : size
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: target))
            if rotation { context.cgContext.translateBy(x: target.width, y: 0); context.cgContext.rotate(by: .pi / 2) }
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.85) else { throw ScanError.invalidImage }
        return data
    }
}

enum ScanError: Error { case invalidImage, tooManyPages, backupFailed }

enum OCRTranscript {
    static let placeholder = "[待确认]"
    static let uncertainConfidence: Float = 0.45

    static func readingOrder(_ lines: [OCRLineDocument]) -> [OCRLineDocument] {
        lines.sorted { lhs, rhs in
            if abs(lhs.y - rhs.y) > 0.015 { return lhs.y > rhs.y }
            return lhs.x < rhs.x
        }
    }

    static func normalizedLine(_ line: OCRLineDocument) -> OCRLineDocument {
        guard line.confidence < uncertainConfidence else { return line }
        let candidates = ([line.text] + line.alternatives).filter { !$0.isEmpty && $0 != placeholder }
        return OCRLineDocument(
            id: line.id, text: placeholder, confidence: line.confidence, alternatives: candidates,
            x: line.x, y: line.y, width: line.width, height: line.height
        )
    }

    static func joined(_ lines: [OCRLineDocument]) -> String {
        lines.map(\.text).joined(separator: "\n")
    }

    static func containsUnresolved(_ text: String) -> Bool { text.contains(placeholder) }
}

enum ScanImageBackupPath {
    static func objectPath(userID: UUID, pageID: UUID) -> String? {
        let user = userID.uuidString.lowercased()
        let page = pageID.uuidString.lowercased()
        guard user.range(of: #"^[0-9a-f-]{36}$"#, options: .regularExpression) != nil,
              page.range(of: #"^[0-9a-f-]{36}$"#, options: .regularExpression) != nil else { return nil }
        return "\(user)/scans/\(page).jpg"
    }
}

enum ScanSampleImage {
    static func jpeg(text: String) throws -> Data {
        let size = CGSize(width: 1600, height: 520)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "TimesNewRomanPSMT", size: 72) ?? UIFont.systemFont(ofSize: 72),
                .foregroundColor: UIColor.black,
                .paragraphStyle: style
            ]
            (text as NSString).draw(in: CGRect(x: 48, y: 150, width: 1504, height: 260), withAttributes: attributes)
        }
        guard let data = rendered.jpegData(compressionQuality: 0.95) else { throw ScanError.invalidImage }
        return data
    }
}

