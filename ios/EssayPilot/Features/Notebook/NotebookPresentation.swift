import Foundation

/// Reading order and labels are independent of persistence and SwiftUI.
enum NotebookPresentation {
    struct Section: Identifiable {
        let id: String
        let title: String
        let entries: [NotebookEntry]
    }
    struct LinkSource: Identifiable, Equatable {
        var id: String { title }
        let title: String
        let count: Int
    }
    /// Known platforms keep a stable order; every other site shares one shelf.
    static let sourceOrder = NotebookLink.Platform.allCases.map(\.title) + [NotebookLink.otherSourceTitle]

    static func sections(_ entries: [NotebookEntry], filter: String, search: String, source: String? = nil, now: Date = .now, calendar: Calendar = .current) -> [Section] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = entries.filter { entry in
            entry.deletedAt == nil &&
            (filter == "all" || (filter == "pending" && !entry.completed) || (filter == "links" && entry.safeURL != nil) || (filter == "done" && entry.completed)) &&
            (query.isEmpty || searchText(entry).localizedCaseInsensitiveContains(query))
        }
        if filter == "links" { return sourceSections(visible, only: source) }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        func group(_ entry: NotebookEntry) -> String {
            if entry.completed { return "done" }
            if entry.pinned { return "pinned" }
            if entry.kind != .task { return "moments" }
            if let due = entry.dueDate, due < tomorrow { return "today" }
            return "later"
        }
        return [("pinned", "放在最前面"), ("today", "留给今天"), ("later", "慢慢来的小事"), ("moments", "留下的片刻"), ("done", "已经走过")].compactMap { id, title in
            let rows = visible.filter { group($0) == id }.sorted {
                if id == "done" { return $0.updatedAt == $1.updatedAt ? $0.id.uuidString < $1.id.uuidString : $0.updatedAt > $1.updatedAt }
                if $0.dueDate != $1.dueDate { return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
                return $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt > $1.createdAt
            }
            return rows.isEmpty ? nil : Section(id: id, title: title, entries: rows)
        }
    }
    /// Link shelves by source, for the source chips. Deleted entries never count.
    static func linkSources(_ entries: [NotebookEntry]) -> [LinkSource] {
        let groups = Dictionary(grouping: entries.compactMap { $0.deletedAt == nil ? $0.safeURL.map(NotebookLink.sourceGroup) : nil }, by: { $0 })
        return sourceOrder.compactMap { title in groups[title].map { LinkSource(title: title, count: $0.count) } }
    }
    private static func sourceSections(_ entries: [NotebookEntry], only source: String?) -> [Section] {
        sourceOrder.compactMap { title in
            guard source == nil || source == title else { return nil }
            // Unread first (pinned on top), newest first; links already seen sink to the bottom of their shelf.
            let rows = entries.filter { $0.safeURL.map(NotebookLink.sourceGroup) == title }.sorted {
                if $0.completed != $1.completed { return !$0.completed }
                if $0.pinned != $1.pinned { return $0.pinned }
                return $0.createdAt == $1.createdAt ? $0.id.uuidString < $1.id.uuidString : $0.createdAt > $1.createdAt
            }
            return rows.isEmpty ? nil : Section(id: "source-" + title, title: "\(title) · \(rows.count)", entries: rows)
        }
    }
    private static func searchText(_ entry: NotebookEntry) -> String {
        var text = entry.title + " " + entry.note + " " + (entry.link ?? "")
        if let url = entry.safeURL { text += " " + (NotebookLink.platform(url)?.keywords ?? NotebookLink.source(url)) }
        return text
    }
    static func dateLabel(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "今天" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) { return "明天" }
        let value = date.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).month().day())
        return date < calendar.startOfDay(for: now) ? "\(value) · 还可以接着做" : value
    }
    static func preview(_ entry: NotebookEntry) -> String {
        var text = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if entry.safeURL != nil { text = NotebookLink.removingLinks(text) }
        // Auto titles come from the first line or a 【shared title】; don't repeat them under the title.
        let first = text.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? ""
        if !entry.title.isEmpty, first == entry.title || first.trimmingCharacters(in: CharacterSet(charactersIn: "【】 ")).hasPrefix(entry.title) {
            text = text.components(separatedBy: .newlines).dropFirst().joined(separator: "\n")
        }
        return text.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func completionLabel(_ entry: NotebookEntry) -> String {
        if entry.completed { return entry.kind == .task ? "重新打开" : "再放回手边" }
        switch entry.kind { case .task: return "完成"; case .note: return "收好这段话"; case .link: return "标记看过" }
    }
}
