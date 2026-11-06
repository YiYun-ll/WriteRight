import Foundation

enum PracticeInputMode: String, Codable, CaseIterable, Identifiable {
    case text, photos
    var id: String { rawValue }
    var title: String { self == .text ? "文字" : "照片" }
}

struct PracticeTextInputs: Codable, Equatable {
    var task: String
    var essay: String
}

enum PracticeFingerprint {
    static func hash(part: WritingPart, reference: String?, text: PracticeTextInputs?, sources: [String]) -> String {
        var components = [part.rawValue]
        if let reference, !reference.isEmpty { components.append(reference) }
        if let text { components += ["task-text:\(text.task)", "essay-text:\(text.essay)"] }
        return ContentFingerprint.hash((components + sources).joined(separator: "\n"))
    }
}

extension DraftDocument {
    var practiceSummary: String {
        let detail: String
        if resolvedAnswerMode == .photos { detail = "\(pages?.count ?? 0) 页原稿" }
        else if task.part == .translation { detail = "\(body.filter { !$0.isWhitespace }.count) 字" }
        else { detail = "\(wordCount) 词" }
        return "\(task.part.title) · \(detail)"
    }
    var resolvedTaskMode: PracticeInputMode { taskInputMode ?? ((task.sourcePages?.isEmpty == false || source == "photos") && task.prompt.isEmpty ? .photos : .text) }
    var resolvedAnswerMode: PracticeInputMode { answerInputMode ?? (source == "photos" || (pages?.isEmpty == false && body.isEmpty) ? .photos : .text) }
    var activePracticeDraft: DraftDocument {
        var active = self
        if resolvedTaskMode == .text { active.task.sourcePages = [] }
        else { active.task.prompt = ""; active.task.confirmedAt = nil }
        if resolvedAnswerMode == .text { active.pages = []; active.transcriptionConfirmed = true }
        else { active.body = "" }
        return active
    }
    var mixedTextInputs: PracticeTextInputs? {
        let active = activePracticeDraft
        guard !(active.task.sourcePages ?? []).isEmpty || !(active.pages ?? []).isEmpty,
              !active.task.prompt.isEmpty || !active.body.isEmpty else { return nil }
        return .init(task: active.task.prompt, essay: active.body)
    }
    func matches(_ submission: SubmissionDocument) -> Bool {
        let active = activePracticeDraft
        guard submission.draftID == id, active.task.part == submission.task.part,
              active.task.referenceTranslation == submission.task.referenceTranslation,
              (active.task.sourcePages ?? []).map(\.id) == (submission.task.sourcePages ?? []).map(\.id),
              (active.pages ?? []).map(\.id) == (submission.essayPages ?? []).map(\.id) else { return false }
        if let input = submission.textInputs {
            return input == mixedTextInputs
        }
        if submission.essayPages != nil { return active.task.prompt.isEmpty && active.body.isEmpty }
        return active.body == submission.originalText && active.task.prompt == submission.task.prompt
    }
}
