import Foundation

/// Changes only layout whitespace in a new, still-unconfirmed transcript.
/// The original line text, image, spelling and numeric readings remain untouched.
enum OCRLayout {
    struct ReviewText {
        let text: String
        let lineRanges: [UUID: NSRange]
    }

    static func review(_ lines: [OCRLineDocument], joinsWrappedLines: Bool) -> ReviewText {
        var text = ""
        var ranges: [UUID: NSRange] = [:]
        let heights = lines.map(\.height).filter { $0 > 0 }.sorted()
        let height = heights.isEmpty ? 0.025 : heights[heights.count / 2]
        let left = lines.map(\.x).min() ?? 0
        let gaps = zip(lines, lines.dropFirst()).map { previous, next in
            max(0, previous.y - next.y - next.height)
        }.sorted()
        let normalGap = min(gaps.isEmpty ? 0 : gaps[gaps.count / 2], height * 0.6)
        for (index, line) in lines.enumerated() {
            if index > 0 {
                let previous = lines[index - 1]
                if !joinsWrappedLines {
                    text += "\n"
                } else {
                    let gap = previous.y - line.y - line.height
                    let endsSentence = previous.text.last.map { ".!?。！？".contains($0) } ?? false
                    let indented = line.x - left > max(0.025, height * 0.8)
                    let salutation = previous.text.lowercased().hasPrefix("dear ") && previous.text.hasSuffix(",")
                    let closing = previous.text.lowercased().hasPrefix("yours ") || previous.text.lowercased() == "sincerely,"
                    let separateColumn = line.x > previous.x + previous.width + 0.04
                    let paragraph = gap > max(height * 0.9, normalGap * 1.8)
                        || (indented && endsSentence) || salutation || closing
                        || line.text.lowercased().hasPrefix("yours ") || separateColumn
                    text += paragraph ? "\n\n" : " "
                }
            }
            ranges[line.id] = NSRange(location: text.utf16.count, length: line.text.utf16.count)
            text += line.text
        }
        return ReviewText(text: text, lineRanges: ranges)
    }

    /// Refuses to replace by a stale line index after a manual edit or AI adoption.
    static func replacingCandidate(in editedText: String, lines: [OCRLineDocument], lineID: UUID,
                                   with candidate: String, joinsWrappedLines: Bool) -> String? {
        let formatted = review(lines, joinsWrappedLines: joinsWrappedLines)
        let raw = review(lines, joinsWrappedLines: false)
        let layout: ReviewText
        if editedText == formatted.text { layout = formatted }
        else if editedText == raw.text { layout = raw }
        else { return nil }
        guard let range = layout.lineRanges[lineID], let swiftRange = Range(range, in: editedText) else { return nil }
        return editedText.replacingCharacters(in: swiftRange, with: candidate)
    }
}
