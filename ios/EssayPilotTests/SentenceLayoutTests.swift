import XCTest
#if canImport(EssayPilot)
@testable import EssayPilot
#endif

final class SentenceLayoutTests: XCTestCase {
    func testSoftOCRWrapsRemainInsideOneSourceSentence() {
        let text = "I has\nprepared a book. It is useful.\n\nAnother paragraph."
        let rows = SentenceSegmenter.sentences(in: text)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.first?.original, "I has\nprepared a book.")
        XCTAssertEqual(rows.last?.paragraphIndex, 1)
        for row in rows {
            XCTAssertEqual((text as NSString).substring(with: NSRange(location: row.startUTF16, length: row.lengthUTF16)), row.original)
        }
    }
    func testCRLFAndUnicodeKeepExactSourceOffsets() {
        let text = "😀 I recieved\r\na letter.\r\n \t\r\nThe rate is 3.5%."
        let rows = SentenceSegmenter.sentences(in: text)
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows[0].original.contains("recieved\r\na"))
        XCTAssertEqual(rows[1].paragraphIndex, 1)
        for row in rows {
            XCTAssertEqual((text as NSString).substring(with: NSRange(location: row.startUTF16, length: row.lengthUTF16)), row.original)
        }
    }
}
