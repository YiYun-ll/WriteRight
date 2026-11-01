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
    enum Platform: String, CaseIterable, Sendable {
        case bilibili, wechat, xiaohongshu, douyin
        var title: String { switch self { case .bilibili: "哔哩哔哩"; case .wechat: "微信公众号"; case .xiaohongshu: "小红书"; case .douyin: "抖音" } }
        /// Words people actually type when searching for a source.
        var keywords: String { switch self { case .bilibili: "哔哩哔哩 B站 b站 bilibili"; case .wechat: "微信公众号 公众号 微信 weixin"; case .xiaohongshu: "小红书 xhs"; case .douyin: "抖音 douyin" } }
        fileprivate var hosts: [String] {
            switch self {
            case .bilibili: ["bilibili.com", "b23.tv", "bili2233.cn"]
            case .wechat: ["mp.weixin.qq.com"]
            case .xiaohongshu: ["xiaohongshu.com", "xhslink.com"]
            case .douyin: ["douyin.com", "iesdouyin.com"]
            }
        }
        fileprivate func matches(_ host: String) -> Bool { hosts.contains { host == $0 || host.hasSuffix("." + $0) } }
    }
    static let otherSourceTitle = "其他网站"

    /// Share text is data. Never fetch it or accept executable/custom URL schemes.
    /// Plain HTTP is accepted only for known share hosts (Xiaohongshu still hands out http short links) and is upgraded to HTTPS.
    static func url(_ text: String) -> URL? {
        guard text.utf8.count <= 16000 else { return nil }
        // ASCII-only URL characters, so Chinese share text glued to the link ("…/abc，复制本条信息") is not swallowed.
        let pattern = #"(?i)https?://[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+"#
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: pattern, options: .regularExpression, range: searchRange) {
            searchRange = range.upperBound..<text.endIndex
            let candidate = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?'）)]}"))
            if let url = validated(candidate) { return url }
        }
        return nil
    }
    /// Text with every http(s) address removed, for previews and for telling bare links from share text.
    static func removingLinks(_ text: String) -> String {
        text.replacingOccurrences(of: #"(?i)https?://[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+"#, with: "", options: .regularExpression)
    }
    private static func validated(_ candidate: String) -> URL? {
        guard candidate.count <= 4000, var parts = URLComponents(string: candidate),
              let scheme = parts.scheme?.lowercased(), parts.user == nil, parts.password == nil,
              let host = parts.host?.lowercased(), host.contains("."),
              host != "127.0.0.1", host != "0.0.0.0", !host.hasSuffix(".local") else { return nil }
        if scheme == "http" {
            guard Platform.allCases.contains(where: { $0.matches(host) }) else { return nil }
        } else if scheme != "https" { return nil }
        parts.scheme = "https"
        return parts.url
    }
    static func platform(_ url: URL) -> Platform? {
        let host = url.host?.lowercased() ?? ""
        return Platform.allCases.first { $0.matches(host) }
    }
    static func source(_ url: URL) -> String {
        if let platform = platform(url) { return platform.title }
        let host = url.host?.lowercased() ?? ""
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
    /// Grouping label for the link shelf: known platforms by name, everything else together.
    static func sourceGroup(_ url: URL) -> String { platform(url)?.title ?? otherSourceTitle }
    /// Share text such as "【标题-哔哩哔哩】 https://b23.tv/…" already carries a title; never fetched from the network.
    static func suggestedTitle(_ text: String) -> String? {
        guard let range = text.range(of: #"【([^【】\n]{2,120})】"#, options: .regularExpression) else { return wordsBeforeLink(text) }
        var title = String(text[range].dropFirst().dropLast())
        for suffix in ["_哔哩哔哩_bilibili", "-哔哩哔哩_bilibili", "_哔哩哔哩", "-哔哩哔哩", "_bilibili"] where title.hasSuffix(suffix) {
            title = String(title.dropLast(suffix.count)); break
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let appNames = ["小红书", "抖音", "哔哩哔哩", "bilibili", "微信", "快手"]
        if title.count >= 2, !appNames.contains(title.lowercased()) { return title }
        return wordsBeforeLink(text)
    }
    private static func wordsBeforeLink(_ text: String) -> String? {
        guard let link = text.range(of: #"(?i)https?://"#, options: .regularExpression) else { return nil }
        let lineStart = text[..<link.lowerBound].lastIndex(where: \.isNewline).map { text.index(after: $0) } ?? text.startIndex
        let words = text[lineStart..<link.lowerBound]
            .replacingOccurrences(of: #"【[^】]*】"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard words.count >= 2, !words.contains("复制") else { return nil }
        return String(words.prefix(60))
    }
}
