import Foundation

struct NotebookEntry: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable { case task, note, link
        var id: String { rawValue }
        var title: String { switch self { case .task: "待办"; case .note: "随手记"; case .link: "灵感链接" } }
    }
    var id = UUID()
    var kind: Kind = .task
    var title: String
    var note = ""
    var link: String? = nil
    var dueDate: Date? = nil
    var completed = false
    var pinned = false
    var createdAt = Date()
    var updatedAt = Date()
    var deletedAt: Date? = nil
    var safeURL: URL? { link.flatMap(NotebookLink.url) }
}

struct NotebookChange: Sendable {
    var entry: NotebookEntry
    var revision: Int64
    var dirty: Bool
}

enum NotebookLink {
    /// Share text is data. Never fetch it or accept executable/custom URL schemes.
    static func url(_ text: String) -> URL? {
        guard text.utf8.count <= 16000,
              let range = text.range(of: #"https://[^\s<>"“”]+"#, options: .regularExpression) else { return nil }
        let candidate = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: "，。！？；、）)]}…"))
        guard let parts = URLComponents(string: candidate), parts.scheme?.lowercased() == "https",
              parts.user == nil, parts.password == nil, let host = parts.host?.lowercased(),
              host.contains("."), host != "127.0.0.1", host != "0.0.0.0", !host.hasSuffix(".local"),
              candidate.count <= 4000 else { return nil }
        return parts.url
    }
    static func source(_ url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host == "douyin.com" || host.hasSuffix(".douyin.com") { return "抖音" }
        if ["xiaohongshu.com", "xhslink.com"].contains(where: { host == $0 || host.hasSuffix("." + $0) }) { return "小红书" }
        return host
    }
}
