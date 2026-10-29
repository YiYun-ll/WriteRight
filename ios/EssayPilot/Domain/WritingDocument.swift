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

    static func empty(part: WritingPart) -> Self {
        .init(id: UUID(), part: part, title: "", prompt: "", requirements: [], revision: 1)
    }

    var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        let line = prompt.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.isEmpty ? "\(part.title)练习" : String(line.prefix(42))
    }
    var isConfirmed: Bool { confirmedAt != nil && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct DraftDocument: Codable, Identifiable, Equatable {
    var id: UUID
    var task: WritingTaskDocument
    var body: String
    var source: String
    var transcriptionConfirmed: Bool
    var createdAt: Date
    var updatedAt: Date

    var wordCount: Int { WordCounter.count(body) }
    var isEmpty: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
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
}

@MainActor
protocol WritingRepository: AnyObject {
    func drafts() throws -> [DraftDocument]
    func submissions() throws -> [SubmissionDocument]
    func save(_ draft: DraftDocument) throws
    func saveSubmission(_ submission: SubmissionDocument) throws
    func deleteDraft(id: UUID) throws
    func exportData() throws -> Data
}
