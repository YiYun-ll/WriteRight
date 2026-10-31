import Foundation

/// Reading order and labels are independent of persistence and SwiftUI.
enum NotebookPresentation {
    struct Section: Identifiable {
        let id: String
        let title: String
        let entries: [NotebookEntry]
    }
    static func sections(_ entries: [NotebookEntry], filter: String, search: String, now: Date = .now, calendar: Calendar = .current) -> [Section] {
        let visible = entries.filter { entry in
            entry.deletedAt == nil &&
            (filter == "all" || (filter == "pending" && !entry.completed) || (filter == "links" && entry.safeURL != nil) || (filter == "done" && entry.completed)) &&
            (search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (entry.title + " " + entry.note + " " + (entry.link ?? "")).localizedCaseInsensitiveContains(search.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
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
    static func dateLabel(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "今天" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) { return "明天" }
        let value = date.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).month().day())
        return date < calendar.startOfDay(for: now) ? "\(value) · 还可以接着做" : value
    }
    static func preview(_ entry: NotebookEntry) -> String {
        var text = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.components(separatedBy: .newlines).first == entry.title {
            text = text.components(separatedBy: .newlines).dropFirst().joined(separator: "\n")
        }
        if let url = entry.safeURL { text = text.replacingOccurrences(of: url.absoluteString, with: "") }
        return text.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func completionLabel(_ entry: NotebookEntry) -> String {
        if entry.completed { return entry.kind == .task ? "重新打开" : "再放回手边" }
        switch entry.kind { case .task: return "完成"; case .note: return "收好这段话"; case .link: return "标记看过" }
    }
}
