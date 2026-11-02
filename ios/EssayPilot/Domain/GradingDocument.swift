import Foundation

enum GradingJobState: String, Codable {
    case queued, running, completed, failed
}

enum GradingStage: String, Codable {
    case evaluate, correct, rewrite, validate, done
}

struct GradingJobDocument: Codable, Identifiable, Equatable {
    let id: UUID
    let submissionID: UUID
    let idemKey: UUID
    var status: GradingJobState
    var stage: GradingStage
    var errorCode: String?
    var updatedAt: Date
}

struct GradingStatusResponse: Codable {
    let jobId: UUID
    let status: GradingJobState
    let stage: GradingStage
    let report: GradingReportDocument?
    let errorCode: String?
}

struct GradingReportChange {
    let report: GradingReportDocument
    let baseRevision: Int64
    let deleted: Bool
    let dirty: Bool
}

struct GradingReportDocument: Codable, Identifiable, Equatable {
    let id: UUID
    let jobID: UUID
    let submissionID: UUID
    let part: WritingPart
    let report: GradingReportPayload
    let sentences: [SentenceSpan]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case jobID = "job_id"
        case submissionID = "submission_id"
        case part
        case report = "report_json"
        case sentences = "source_sentences_json"
        case createdAt = "created_at"
    }
}

struct GradingReportPayload: Codable, Equatable {
    let schemaVersion: String
    let part: WritingPart
    let gradingMode: String
    let score: ReportScore
    let wordCount: Int
    let rubricVersion: String
    let promptVersion: String
    let modelID: String
    let overallComment: String
    let dimensions: [ReportDimension]
    let taskChecks: [ReportTaskCheck]
    let corrections: [ReportCorrection]
    let rewrites: ReportRewrites
    let review: ReportReview
    var photoReview: PhotoReviewPayload? = nil
    var sentenceReviews: SentenceReviews? = nil
    var advancedAdvice: [AdvancedAdvice]? = nil
    var modelEssay: ModelEssay? = nil

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case part
        case gradingMode = "grading_mode"
        case score
        case wordCount = "word_count"
        case rubricVersion = "rubric_version"
        case promptVersion = "prompt_version"
        case modelID = "model_id"
        case overallComment = "overall_comment"
        case dimensions
        case taskChecks = "task_checks"
        case corrections, rewrites, review
        case sentenceReviews = "sentence_reviews"
        case advancedAdvice = "advanced_advice", modelEssay = "model_essay"
        case photoReview = "photo_review"
    }
}

struct PhotoSource: Codable, Equatable, Identifiable, Sendable {
    let role: String
    let page: Int
    let path: String
    let checksum: String
    var id: String { path }
}

struct PhotoReviewPayload: Codable, Equatable {
    struct Uncertainty: Codable, Equatable {
        let role: String
        let page: Int?
        let message: String
        let blocksScoring: Bool
        enum CodingKeys: String, CodingKey { case role, page, message; case blocksScoring = "blocks_scoring" }
    }
    struct Correction: Codable, Equatable {
        let page: Int
        let original: String
        let corrected: String
        let reason: String
        let category: String
        let severity: String
    }
    let sources: [PhotoSource]
    let taskFingerprint: String?
    let taskStatus: String
    let strengths: [String]
    let uncertainties: [Uncertainty]
    let corrections: [Correction]
    let wordCountEstimated: Bool
    enum CodingKeys: String, CodingKey {
        case sources, strengths, uncertainties, corrections
        case taskFingerprint = "task_fingerprint", taskStatus = "task_status", wordCountEstimated = "word_count_estimated"
    }
}

struct ReportScore: Codable, Equatable {
    let value: Double?
    let max: Int
    let band: String?
    let range: [Double]?
    let confidence: String
}

struct ReportDimension: Codable, Equatable {
    let name: String
    let level: String
    let explanation: String
    let evidenceSentenceIDs: [String]

    enum CodingKeys: String, CodingKey {
        case name, level, explanation
        case evidenceSentenceIDs = "evidence_sentence_ids"
    }
}

struct ReportTaskCheck: Codable, Equatable {
    let pointID: String
    let status: String
    let reason: String
    let evidenceSentenceIDs: [String]

    enum CodingKeys: String, CodingKey {
        case pointID = "point_id"
        case status, reason
        case evidenceSentenceIDs = "evidence_sentence_ids"
    }
}

struct ReportCorrection: Codable, Equatable, Identifiable {
    let sentenceID: String
    let original: String
    let minimalCorrected: String
    let category: String
    let severity: String
    let impact: String
    let reasonZH: String
    let optionalUpgrade: String?
    var id: String { sentenceID }

    enum CodingKeys: String, CodingKey {
        case sentenceID = "sentence_id"
        case original
        case minimalCorrected = "minimal_corrected"
        case category, severity, impact
        case reasonZH = "reason_zh"
        case optionalUpgrade = "optional_upgrade"
    }
}

struct ReportRewrites: Codable, Equatable {
    let minimal: String
    let enhanced: String
    var study: RewriteStudy? = nil
}

struct RewriteStudy: Codable, Equatable {
    let minimal: RewriteStudyVersion
    let enhanced: RewriteStudyVersion
}
struct RewriteStudyVersion: Codable, Equatable {
    let translationZH: String
    let highlights: [RewriteHighlight]
    enum CodingKeys: String, CodingKey { case translationZH = "translation_zh", highlights }

    func validHighlights(in text: String) -> [RewriteHighlight] {
        var used: [Range<String.Index>] = []
        return highlights.prefix(3).filter { item in
            guard !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let range = text.range(of: item.text),
                  text.range(of: item.text, range: text.index(after: range.lowerBound)..<text.endIndex) == nil,
                  !used.contains(where: { $0.overlaps(range) }) else { return false }
            used.append(range); return true
        }
    }
}
struct RewriteHighlight: Codable, Equatable {
    let text: String
    let reasonZH: String
    enum CodingKeys: String, CodingKey { case text, reasonZH = "reason_zh" }
}

struct ReportReview: Codable, Equatable {
    let topIssues: [String]
    let expressions: [ReviewExpression]
    let practiceAdvice: String

    enum CodingKeys: String, CodingKey {
        case topIssues = "top_issues"
        case expressions
        case practiceAdvice = "practice_advice"
    }
}

struct ReviewExpression: Codable, Equatable {
    let expression: String
    let meaning: String
    let usage: String
}

struct AdvancedAdvice: Codable, Equatable {
    let focus: String
    let observationZH: String
    let before: String
    let after: String
    let whyZH: String
    let practiceZH: String
    let page: Int?
    enum CodingKeys: String, CodingKey {
        case focus, before, after, page
        case observationZH = "observation_zh", whyZH = "why_zh", practiceZH = "practice_zh"
    }
}
struct ModelEssay: Codable, Equatable {
    let english: String
    let translationZH: String
    let highlights: [RewriteHighlight]
    let rationaleZH: String
    enum CodingKeys: String, CodingKey { case english, highlights; case translationZH = "translation_zh", rationaleZH = "rationale_zh" }
    var study: RewriteStudyVersion { .init(translationZH: translationZH, highlights: highlights) }
}

struct SentenceReviews: Codable, Equatable {
    let coverage: String
    let noticeZH: String
    let items: [SentenceReviewItem]
    enum CodingKeys: String, CodingKey { case coverage, items; case noticeZH = "notice_zh" }
}
struct SentenceReviewItem: Codable, Equatable, Identifiable {
    let index: Int
    let sentenceID: String?
    let page: Int?
    let original: String
    let revised: String?
    let status: String
    let reasonZH: String
    var id: Int { index }
    enum CodingKeys: String, CodingKey {
        case index, page, original, revised, status
        case sentenceID = "sentence_id", reasonZH = "reason_zh"
    }
}
