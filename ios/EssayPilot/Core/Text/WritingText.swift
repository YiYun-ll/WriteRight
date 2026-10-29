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
        text.enumerateSubstrings(in: text.startIndex..., options: .byParagraphs) { paragraph, range, _, _ in
            defer { paragraphIndex += 1 }
            guard let paragraph, !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let paragraphOffset = NSRange(range, in: text).location
            let tokenizer = NLTokenizer(unit: .sentence)
            tokenizer.string = paragraph
            tokenizer.setLanguage(.english)
            tokenizer.enumerateTokens(in: paragraph.startIndex..<paragraph.endIndex) { sentenceRange, _ in
                let raw = String(paragraph[sentenceRange])
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return true }
                let leading = raw.prefix(while: \.isWhitespace).utf16.count
                result.append(.init(
                    id: "s\(result.count + 1)", paragraphIndex: paragraphIndex, original: trimmed,
                    startUTF16: paragraphOffset + NSRange(sentenceRange, in: paragraph).location + leading,
                    lengthUTF16: trimmed.utf16.count
                ))
                return true
            }
        }
        return result
    }
}

enum ContentFingerprint {
    static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
