import CryptoKit
import Foundation
import NaturalLanguage

enum WordCounter {
    private static let expression = try! NSRegularExpression(
        pattern: #"[A-Za-z]+(?:['’][A-Za-z]+)*(?:[-‑][A-Za-z]+(?:['’][A-Za-z]+)*)*|[0-9]+(?:[.,][0-9]+)*%?"#
    )

    static func count(_ text: String) -> Int {
        expression.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }
}

enum SentenceSegmenter {
    static func sentences(in text: String) -> [SentenceSpan] {
        var result: [SentenceSpan] = []
        var paragraphIndex = 0
        let source = text as NSString
        let gaps = try! NSRegularExpression(pattern: #"\r?\n[ \t]*\r?\n(?:[ \t]*\r?\n)*"#)
        var start = 0
        var paragraphs: [NSRange] = []
        for match in gaps.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            paragraphs.append(NSRange(location: start, length: match.range.location - start))
            start = NSMaxRange(match.range)
        }
        paragraphs.append(NSRange(location: start, length: source.length - start))
        for range in paragraphs {
            let paragraph = source.substring(with: range)
            guard !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let shadow = paragraph.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
            let tokenizer = NLTokenizer(unit: .sentence)
            tokenizer.string = shadow
            tokenizer.setLanguage(.english)
            tokenizer.enumerateTokens(in: shadow.startIndex..<shadow.endIndex) { sentenceRange, _ in
                let rawRange = NSRange(sentenceRange, in: shadow)
                let raw = (paragraph as NSString).substring(with: rawRange)
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return true }
                let leading = raw.prefix(while: \.isWhitespace).utf16.count
                result.append(.init(
                    id: "s\(result.count + 1)", paragraphIndex: paragraphIndex, original: trimmed,
                    startUTF16: range.location + rawRange.location + leading,
                    lengthUTF16: trimmed.utf16.count
                ))
                return true
            }
            paragraphIndex += 1
        }
        return result
    }
}

enum ContentFingerprint {
    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
