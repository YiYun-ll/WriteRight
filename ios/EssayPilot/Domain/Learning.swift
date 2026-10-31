import Foundation

struct FavoriteSource: Codable, Equatable, Sendable {
    var reportID: UUID
    var sentence: String
}

struct FavoriteDocument: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var expression: String
    var normalized: String
    var meaning: String
    var usage: String
    var sources: [FavoriteSource]
    var createdAt: Date
    var deletedAt: Date?

    static func normalize(_ text: String) -> String {
        text.lowercased().split { $0.isWhitespace || $0.isNewline }.joined(separator: " ")
    }

    static func make(expression: String, meaning: String, usage: String, reportID: UUID, sentence: String) -> Self {
        .init(
            id: UUID(), expression: expression, normalized: normalize(expression), meaning: meaning, usage: usage,
            sources: [FavoriteSource(reportID: reportID, sentence: sentence)], createdAt: .now, deletedAt: nil
        )
    }

    func merging(meaning: String, usage: String, source: FavoriteSource) -> Self {
        var copy = self
        if copy.meaning.isEmpty { copy.meaning = meaning }
        if copy.usage.isEmpty { copy.usage = usage }
        if !copy.sources.contains(where: { $0.reportID == source.reportID && $0.sentence == source.sentence }) {
            copy.sources.append(source)
        }
        copy.deletedAt = nil
        return copy
    }
}

struct FavoriteChange: Equatable, Sendable {
    var favorite: FavoriteDocument
    var baseRevision: Int64
    var deleted: Bool
    var dirty: Bool
}

struct DraftChange: Equatable, Sendable {
    var draft: DraftDocument
    var baseRevision: Int64
    var deleted: Bool
    var dirty: Bool
}

struct ScorePoint: Equatable, Sendable {
    var date: Date
    var part: WritingPart
    var score: Double
    var max: Int
    var rubricVersion: String
    var requiredErrors: Int
    var wordCount: Int
    var sentenceCount: Int
    var passedChecks: Int
    var taskID: UUID
    var submissionID: UUID
    var estimatedSource: Bool = false
}

enum PracticeAnalytics {
    static let ratioCaption = "分数 / 满分"
    static func points(submissions: [SubmissionDocument], reports: [GradingReportDocument]) -> [ScorePoint] {
        reports.compactMap { report in
            guard let value = report.report.score.value,
                  let submission = submissions.first(where: { $0.id == report.submissionID }) else { return nil }
            return ScorePoint(
                date: report.createdAt, part: report.part, score: value, max: report.report.score.max,
                rubricVersion: report.report.rubricVersion,
                requiredErrors: report.report.corrections.filter { $0.severity == "required" }.count,
                wordCount: max(report.report.wordCount, submission.wordCount),
                sentenceCount: max(report.sentences.count, 1),
                passedChecks: report.report.taskChecks.filter { $0.status == "passed" }.count,
                taskID: submission.task.id, submissionID: submission.id, estimatedSource: report.report.photoReview != nil
            )
        }.sorted { $0.date < $1.date }
    }

    static func series(_ points: [ScorePoint], part: WritingPart) -> [ScorePoint] {
        let matched = points.filter { $0.part == part }
        return matched.count >= 2 ? matched : []
    }

    static func ratios(_ points: [ScorePoint]) -> [(Date, Double)] {
        points.filter { $0.max > 0 }.map { ($0.date, $0.score / Double($0.max)) }
    }

    static func comparable(_ points: [ScorePoint]) -> Bool {
        Set(points.map(\.rubricVersion)).count <= 1
    }

    static func errorsPerHundredWords(_ point: ScorePoint) -> Double? {
        guard point.wordCount > 0 && !point.estimatedSource else { return nil }
        return Double(point.requiredErrors) / Double(point.wordCount) * 100
    }

    static func comparison(taskID: UUID, submissions: [SubmissionDocument], reports: [GradingReportDocument]) -> TaskComparison? {
        guard let referenceSubmission = submissions.first(where: { $0.task.id == taskID }) else { return nil }
        let reference = referenceSubmission.task
        if referenceSubmission.originalText.isEmpty && reference.photoFingerprint == nil { return nil }
        let pair = submissions.filter { candidate in
            guard candidate.task.part == reference.part else { return false }
            if let fingerprint = reference.photoFingerprint {
                return candidate.task.photoFingerprint == fingerprint
            }
            return candidate.task.id == taskID && candidate.task.photoFingerprint == nil
        }.filter { item in reports.contains { $0.submissionID == item.id } }.sorted { $0.submittedAt < $1.submittedAt }
        guard pair.count >= 2 else { return nil }
        let left = pair[pair.count - 2]
        let right = pair[pair.count - 1]
        let leftReport = reports.first { $0.submissionID == left.id }
        let rightReport = reports.first { $0.submissionID == right.id }
        let sameRubric = leftReport?.report.rubricVersion == rightReport?.report.rubricVersion
        let bothScored = leftReport?.report.score.value != nil && rightReport?.report.score.value != nil
        return TaskComparison(
            left: left, right: right, leftScore: leftReport?.report.score.value, rightScore: rightReport?.report.score.value,
            leftPassed: leftReport?.report.taskChecks.filter { $0.status == "passed" }.count ?? 0,
            rightPassed: rightReport?.report.taskChecks.filter { $0.status == "passed" }.count ?? 0,
            leftErrors: leftReport?.report.corrections.filter { $0.severity == "required" }.count ?? 0,
            rightErrors: rightReport?.report.corrections.filter { $0.severity == "required" }.count ?? 0,
            comparable: sameRubric && bothScored
        )
    }
}

struct TaskComparison: Equatable {
    var left: SubmissionDocument
    var right: SubmissionDocument
    var leftScore: Double?
    var rightScore: Double?
    var leftPassed: Int
    var rightPassed: Int
    var leftErrors: Int
    var rightErrors: Int
    var comparable: Bool
}
