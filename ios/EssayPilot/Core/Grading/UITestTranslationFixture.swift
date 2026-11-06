#if DEBUG
import Foundation

/// Synthetic UI fixture. This path is selected only by the existing UI-test launch flags.
enum UITestTranslationFixture {
    static let english = "Reading opens doors. It helps us understand others."
    static let student = "阅读打开大们。它帮助我们理解别人。"
    static func response(task: WritingTaskDocument, submissionID: UUID, jobID: UUID, photo: PhotoReviewPayload? = nil) -> GradingStatusResponse {
        let full = photo.map { $0.sources.contains { $0.role == "task" } || !($0.textSources?.task ?? "").isEmpty } ?? task.isConfirmed
        let expressions: [ReviewExpression] = [
            .init(expression: "open doors", meaning: "带来机会", usage: "结合语境翻译比喻含义。"),
            .init(expression: "help somebody do", meaning: "帮助某人做某事", usage: "help 后的宾语是动作执行者。"),
            .init(expression: "understand others", meaning: "理解他人", usage: "others 作为代词，不必加名词。")
        ]
        let sentences: [TranslationReview.Sentence] = full ? [
            .init(index: 1, sourcePage: photo == nil ? nil : 1, answerPage: photo == nil ? nil : 1,
                  english: "Reading opens doors.", student: "阅读打开大们。", status: "reviewed",
                  points: [.init(meaning: "阅读拓宽机会", max: 7, earned: 7, explanation: "比喻含义基本保留，非语义错字另计。")],
                  analysis: "doors 是机会的比喻，不必逐字照抄参考译文。", structure: "Reading 为主语，opens 为谓语，doors 为宾语。", revised: "阅读打开大门。"),
            .init(index: 2, sourcePage: photo == nil ? nil : 1, answerPage: photo == nil ? nil : 1,
                  english: "It helps us understand others.", student: "它帮助我们理解别人。", status: "reviewed",
                  points: [.init(meaning: "理解他人", max: 8, earned: 8, explanation: "指代与动作关系准确，保留。")],
                  analysis: "It 指代阅读，help 后可直接接动词原形。", structure: "help somebody do 表示帮助某人做某事。", revised: "它帮助我们理解别人。")
        ] : []
        let revision = full ? "阅读打开大门。它帮助我们理解别人。" : ""
        let review = TranslationReview(sourceStatus: full ? "readable" : "missing", answerStatus: "readable", coverage: full ? "complete" : "unreadable", noticeZH: full ? "" : "请补充英文原文。", overallComment: "主干信息完整，注意中文用字。", accuracy: "两句核心意思准确。", completeness: "两句均已翻译。", fluency: "可以保留表达并修正错别字。", sentences: sentences, typos: full ? [.init(original: "大们", corrected: "大门", reason: "不影响原意的中文错别字。")] : [], revisedTranslation: revision, changes: full ? [.init(text: "大门", reasonZH: "修正中文用字，保留原意。")] : [], topIssues: ["核对中文用字"], expressions: expressions, practiceAdvice: "重读中文译文，确认比喻含义和中文用字。")
        let payload = GradingReportPayload(schemaVersion: "3.0.0", part: .translation, gradingMode: full ? "full" : "language_only", score: .init(value: full ? 14.75 : nil, max: 15, band: full ? "13–15 分档" : nil, range: nil, confidence: full ? "medium" : "low"), wordCount: 0, rubricVersion: "KY_EN2_TRANSLATION_V1", promptVersion: "WRITERIGHT_TRANSLATION_V1", modelID: "synthetic-ui", overallComment: review.overallComment, dimensions: [], taskChecks: [], corrections: [], rewrites: .init(minimal: revision, enhanced: revision), review: .init(topIssues: review.topIssues, expressions: expressions, practiceAdvice: review.practiceAdvice), translationReview: review, photoReview: photo)
        let report = GradingReportDocument(id: jobID, jobID: jobID, submissionID: submissionID, part: .translation, report: payload, sentences: [], createdAt: .now)
        return .init(jobId: jobID, status: .completed, stage: .done, report: report, errorCode: nil)
    }
}
#endif
