import Foundation

enum WritingPart: String, Codable, CaseIterable, Identifiable {
    case a = "A"
    case b = "B"

    var id: String { rawValue }
    var title: String { self == .a ? "小作文" : "大作文" }
    var maximumScore: Int { self == .a ? 10 : 15 }
    var suggestedWords: Int { self == .a ? 100 : 150 }
}

struct TaskRequirement: Codable, Identifiable, Equatable {
    var id: String
    var text: String
}

struct WritingTaskDocument: Codable, Identifiable, Equatable {
    var id: UUID
    var part: WritingPart
    var title: String
    var prompt: String
    var requirements: [TaskRequirement]
    var revision: Int
    var confirmedAt: Date?
    var chartFacts: [ChartFactDocument]? = nil
    var sourcePages: [ScanPageDocument]? = nil
    var uncertainFields: [String]? = nil
    var photoFingerprint: String? = nil

    static func empty(part: WritingPart) -> Self {
        .init(id: UUID(), part: part, title: "", prompt: "", requirements: [], revision: 1)
    }

    var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        let line = prompt.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.isEmpty ? "\(part.title)练习" : String(line.prefix(42))
    }
    var isConfirmed: Bool { confirmedAt != nil && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (chartFacts?.allSatisfy(\.confirmedByUser) ?? true) && (uncertainFields?.isEmpty ?? true) }
}

struct DraftDocument: Codable, Identifiable, Equatable {
    var id: UUID
    var task: WritingTaskDocument
    var body: String
    var source: String
    var transcriptionConfirmed: Bool
    var createdAt: Date
    var updatedAt: Date
    var pages: [ScanPageDocument]? = nil
    var conflictOf: UUID? = nil

    var wordCount: Int { WordCounter.count(body) }
    var isEmpty: Bool {
        (pages?.isEmpty ?? true) && (task.sourcePages?.isEmpty ?? true) && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        task.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && task.requirements.isEmpty
    }
}

struct SentenceSpan: Codable, Identifiable, Equatable {
    var id: String
    var paragraphIndex: Int
    var original: String
    var startUTF16: Int
    var lengthUTF16: Int
}

struct SubmissionDocument: Codable, Identifiable, Equatable {
    let id: UUID
    let draftID: UUID
    let task: WritingTaskDocument
    let originalText: String
    let wordCount: Int
    let contentHash: String
    let sentences: [SentenceSpan]
    let submittedAt: Date
    var essayPages: [ScanPageDocument]? = nil
}

@MainActor
protocol WritingRepository: AnyObject {
    func drafts() throws -> [DraftDocument]
    func submissions() throws -> [SubmissionDocument]
    func save(_ draft: DraftDocument) throws
    func saveSubmission(_ submission: SubmissionDocument) throws
    func deleteDraft(id: UUID) throws
    func gradingJobs() throws -> [GradingJobDocument]
    func gradingReports() throws -> [GradingReportDocument]
    func saveGradingJob(_ job: GradingJobDocument) throws
    func saveGradingReport(_ report: GradingReportDocument) throws
    func deleteGradingReport(id: UUID) throws
    func gradingReportChanges() throws -> [GradingReportChange]
    func acknowledgeGradingReport(id: UUID, revision: Int64, deleted: Bool) throws
    func applyRemoteGradingReport(_ report: GradingReportDocument, revision: Int64) throws
    func exportData() throws -> Data
    func notebookChanges() throws -> [NotebookChange]
    func saveNotebook(_ entry: NotebookEntry) throws
    func acknowledgeNotebook(_ entry: NotebookEntry, revision: Int64, deleted: Bool) throws
    func applyNotebook(_ entry: NotebookEntry, revision: Int64) throws
    func notebookCursor() throws -> Int64
    func setNotebookCursor(_ cursor: Int64) throws
    func draftChanges() throws -> [DraftChange]
    /// `pushed` is the payload that was sent; edits made while the push was in flight keep the row dirty.
    func acknowledgeDraft(id: UUID, revision: Int64, deleted: Bool, pushed: DraftDocument?) throws
    func applyRemoteDraft(_ draft: DraftDocument, revision: Int64) throws
    func syncCursor() throws -> Int64
    func setSyncCursor(_ cursor: Int64) throws
    func favoriteChanges() throws -> [FavoriteChange]
    func acknowledgeFavorite(id: UUID, revision: Int64, deleted: Bool, pushed: FavoriteDocument?) throws
    func applyRemoteFavorite(_ favorite: FavoriteDocument, revision: Int64) throws
    func keepFavorite(_ favorite: FavoriteDocument) throws
    func deleteFavorite(id: UUID) throws
    func favorites() throws -> [FavoriteDocument]
}

extension WritingRepository {
    func gradingReportChanges() throws -> [GradingReportChange] { [] }
    func acknowledgeGradingReport(id: UUID, revision: Int64, deleted: Bool) throws {}
    func applyRemoteGradingReport(_ report: GradingReportDocument, revision: Int64) throws {}

    func notebookChanges() throws -> [NotebookChange] { [] }
    func saveNotebook(_ entry: NotebookEntry) throws { throw LocalStoreError.unavailable }
    func acknowledgeNotebook(_ entry: NotebookEntry, revision: Int64, deleted: Bool) throws {}
    func applyNotebook(_ entry: NotebookEntry, revision: Int64) throws {}
    func notebookCursor() throws -> Int64 { 0 }
    func setNotebookCursor(_ cursor: Int64) throws {}

    func draftChanges() throws -> [DraftChange] { [] }
    func acknowledgeDraft(id: UUID, revision: Int64, deleted: Bool, pushed: DraftDocument?) throws {}
    func acknowledgeDraft(id: UUID, revision: Int64, deleted: Bool) throws { try acknowledgeDraft(id: id, revision: revision, deleted: deleted, pushed: nil) }
    func applyRemoteDraft(_ draft: DraftDocument, revision: Int64) throws {}
    func syncCursor() throws -> Int64 { 0 }
    func setSyncCursor(_ cursor: Int64) throws {}
    func favoriteChanges() throws -> [FavoriteChange] { [] }
    func acknowledgeFavorite(id: UUID, revision: Int64, deleted: Bool, pushed: FavoriteDocument?) throws {}
    func acknowledgeFavorite(id: UUID, revision: Int64, deleted: Bool) throws { try acknowledgeFavorite(id: id, revision: revision, deleted: deleted, pushed: nil) }
    func applyRemoteFavorite(_ favorite: FavoriteDocument, revision: Int64) throws {}
    func keepFavorite(_ favorite: FavoriteDocument) throws {}
    func deleteFavorite(id: UUID) throws {}
    func favorites() throws -> [FavoriteDocument] { [] }
}
