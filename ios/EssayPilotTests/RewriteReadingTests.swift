import XCTest
@testable import EssayPilot

final class RewriteReadingTests: XCTestCase {
    func testLegacyRewriteDecodesWithoutInventingTranslation() throws {
        let data = Data(#"{"minimal":"Old version.","enhanced":"Old enhanced."}"#.utf8)
        let old = try JSONDecoder().decode(ReportRewrites.self, from: data)
        XCTAssertEqual(old.minimal, "Old version.")
        XCTAssertNil(old.study)
    }
    func testUnicodeAnchorsRejectInventedRepeatedAndOverlappingQuotes() {
        let text = "😀 We met in 2022. Read this. Read this."
        let value = RewriteStudyVersion(translationZH: "我们在2022年见面。", highlights: [
            .init(text:"We met in 2022.",reasonZH:"准确的时间表达"),
            .init(text:"met in 2022.",reasonZH:"重叠"),
            .init(text:"We met in 2023.",reasonZH:"原稿不存在")])
        XCTAssertEqual(value.validHighlights(in: text).map(\.text), ["We met in 2022."])
        XCTAssertTrue(RewriteStudyVersion(translationZH: "", highlights: [.init(text:"Read this.",reasonZH:"")]).validHighlights(in:text).isEmpty)
    }
    func testBilingualMetadataRoundTripsAlongsideBothVersions() throws {
        let minimal = RewriteStudyVersion(translationZH:"我有一本书。",highlights:[.init(text:"I have a book.",reasonZH:"主谓一致")])
        let enhanced = RewriteStudyVersion(translationZH:"这本书对我很有用。",highlights:[.init(text:"This book is useful to me.",reasonZH:"表达用途")])
        let value = ReportRewrites(minimal:"I have a book.",enhanced:"This book is useful to me.",study:.init(minimal:minimal,enhanced:enhanced))
        let decoded = try JSONDecoder().decode(ReportRewrites.self,from:JSONEncoder().encode(value))
        XCTAssertEqual(value,decoded)
        XCTAssertEqual(decoded.study?.enhanced.validHighlights(in:decoded.enhanced).count,1)
    }
}
