import Foundation
import Combine

@MainActor final class NotebookEditorModel: ObservableObject {
    @Published var entry: NotebookEntry
    @Published var linkInput: String
    @Published var includeLink: Bool
    @Published var schedule: Bool
    @Published var date: Date
    @Published var error: String?
    init(entry: NotebookEntry) {
        self.entry = entry; linkInput = entry.link ?? ""; includeLink = entry.link != nil || entry.kind == .link
        schedule = entry.dueDate != nil; date = entry.dueDate ?? .now
    }
    var detectedURL: URL? {
        if !linkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return NotebookLink.url(linkInput) }
        return entry.kind == .link ? NotebookLink.url(entry.note) : nil
    }
    func prepare() -> NotebookEntry? {
        error = nil
        var saved = entry
        saved.title = saved.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let supplied = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = includeLink || saved.kind == .link ? detectedURL : nil
        if (includeLink && !supplied.isEmpty || saved.kind == .link) && url == nil {
            error = "没有找到有效的 HTTPS 链接。可以粘贴整段分享文字，或改为随手记。"; return nil
        }
        if !supplied.isEmpty, saved.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, url != nil,
           !NotebookLink.removingLinks(supplied).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saved.note = supplied
        }
        saved.link = url?.absoluteString
        if saved.title.isEmpty {
            if let line = saved.note.split(whereSeparator: \.isNewline).first, NotebookLink.url(String(line)) == nil {
                saved.title = String(line.prefix(120))
            } else if let url {
                if let shared = NotebookLink.suggestedTitle(supplied.isEmpty ? saved.note : supplied) {
                    saved.title = String(shared.prefix(120))
                } else {
                    saved.title = NotebookLink.platform(url).map { "\($0.title)里的一点灵感" } ?? "留住这一段灵感"
                }
            }
        }
        guard !saved.title.isEmpty, saved.title.count <= 120, saved.note.count <= 4000 else {
            error = "写下一个标题或一句想留住的话。标题最多120字，补充文字最多4000字。"; return nil
        }
        saved.dueDate = schedule ? date : nil
        return saved
    }
}
