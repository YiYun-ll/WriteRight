import XCTest
#if canImport(EssayPilot)
@testable import EssayPilot
#endif

final class OCRLayoutTests: XCTestCase {
    private func line(_ text: String, x: Double = 0.1, y: Double, width: Double = 0.8) -> OCRLineDocument {
        .init(id: UUID(), text: text, confidence: 1, alternatives: [], x: x, y: y, width: width, height: 0.03)
    }

    func testWrapsJoinWithoutCorrectingSpellingOrNumbers() {
        let lines = [line("I has", y: 0.8), line("prepared 203 questions. 😀", y: 0.76), line("I recieved answers.", y: 0.72)]
        let result = OCRLayout.review(lines, joinsWrappedLines: true)
        XCTAssertEqual(result.text, "I has prepared 203 questions. 😀 I recieved answers.")
        for row in lines {
            XCTAssertEqual((result.text as NSString).substring(with: result.lineRanges[row.id]!), row.text)
        }
    }

    func testParagraphIndentGapAndLetterBoundariesArePreserved() {
        let lines = [line("Dear Alex,", y: 0.9), line("I has an invitation.", y: 0.86),
                     line("A new paragraph.", x: 0.16, y: 0.82), line("The final paragraph.", y: 0.71),
                     line("Yours sincerely,", y: 0.67), line("Li Ming", y: 0.63)]
        XCTAssertEqual(OCRLayout.review(lines, joinsWrappedLines: true).text,
                       "Dear Alex,\n\nI has an invitation.\n\nA new paragraph.\n\nThe final paragraph.\n\nYours sincerely,\n\nLi Ming")
        XCTAssertEqual(OCRLayout.review(lines, joinsWrappedLines: false).text, lines.map(\.text).joined(separator: "\n"))
    }

    func testCandidateReplacementUsesExactRangesAndRejectsManualEdits() throws {
        let lines = [line("😀 [待确认]", y: 0.8), line("and [待确认] here.", y: 0.76)]
        let initial = OCRLayout.review(lines, joinsWrappedLines: true).text
        XCTAssertEqual(OCRLayout.replacingCandidate(in: initial, lines: lines, lineID: lines[1].id,
                                                    with: "and recieve here.", joinsWrappedLines: true),
                       "😀 [待确认] and recieve here.")
        XCTAssertNil(OCRLayout.replacingCandidate(in: "My manual edit", lines: lines, lineID: lines[0].id,
                                                 with: "replacement", joinsWrappedLines: true))
        XCTAssertNil(OCRLayout.replacingCandidate(in: initial, lines: lines, lineID: UUID(),
                                                 with: "replacement", joinsWrappedLines: true))
    }

    func testEmptyAndSingleLineKeepTheirText() {
        XCTAssertEqual(OCRLayout.review([], joinsWrappedLines: true).text, "")
        XCTAssertEqual(OCRLayout.review([line("I has a book.", y: 0.8)], joinsWrappedLines: true).text, "I has a book.")
    }
}
