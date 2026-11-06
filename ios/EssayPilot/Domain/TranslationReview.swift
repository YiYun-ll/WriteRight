import Foundation

struct TranslationReview: Codable, Equatable {
    struct Point: Codable, Equatable {
        let meaning: String
        let max: Double
        let earned: Double?
        let explanation: String
    }
    struct Sentence: Codable, Equatable, Identifiable {
        let index: Int
        let sourcePage: Int?
        let answerPage: Int?
        let english: String
        let student: String
        let status: String
        let points: [Point]
        let analysis: String
        let structure: String
        let revised: String
        var id: Int { index }
        var maximum: Double { points.reduce(0) { $0 + $1.max } }
        var earned: Double { points.reduce(0) { $0 + ($1.earned ?? 0) } }
        enum CodingKeys: String, CodingKey {
            case index, english, student, status, points, analysis, structure, revised
            case sourcePage = "source_page", answerPage = "answer_page"
        }
    }
    struct Typo: Codable, Equatable {
        let original: String
        let corrected: String
        let reason: String
    }
    let sourceStatus: String
    let answerStatus: String
    let coverage: String
    let noticeZH: String
    let overallComment: String
    let accuracy: String
    let completeness: String
    let fluency: String
    let sentences: [Sentence]
    let typos: [Typo]
    let revisedTranslation: String
    let changes: [RewriteHighlight]
    let topIssues: [String]
    let expressions: [ReviewExpression]
    let practiceAdvice: String
    var subtotal: Double { sentences.reduce(0) { $0 + $1.earned } }
    var typoDeduction: Double { Double(typos.count / 3) * 0.5 + (typos.count % 3 == 0 ? 0 : 0.25) }
    enum CodingKeys: String, CodingKey {
        case coverage, accuracy, completeness, fluency, sentences, typos, changes, expressions
        case sourceStatus = "source_status", answerStatus = "answer_status", noticeZH = "notice_zh"
        case overallComment = "overall_comment", revisedTranslation = "revised_translation"
        case topIssues = "top_issues", practiceAdvice = "practice_advice"
    }
}
