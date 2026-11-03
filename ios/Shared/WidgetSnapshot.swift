import AppIntents
import Foundation
import Security
import SwiftUI

enum WidgetTheme: String, AppEnum {
    case paper, sage, midnight, photo
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "背景"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.paper: "暖纸", .sage: "鼠尾草", .midnight: "午夜", .photo: "自选照片"]
    var dark: Bool { self == .midnight || self == .photo }
    var background: Color {
        switch self {
        case .paper: Color(red: 0.975, green: 0.957, blue: 0.918)
        case .sage: Color(red: 0.86, green: 0.90, blue: 0.83)
        case .midnight: Color(red: 0.12, green: 0.17, blue: 0.18)
        case .photo: Color(red: 0.20, green: 0.24, blue: 0.22)
        }
    }
    var ink: Color { dark ? .white : Color(red: 0.19, green: 0.16, blue: 0.13) }
    var secondary: Color { dark ? .white.opacity(0.8) : Color(red: 0.43, green: 0.39, blue: 0.34) }
    var accent: Color { dark ? Color(red: 1, green: 0.76, blue: 0.49) : Color(red: 0.65, green: 0.25, blue: 0.13) }
}

enum WidgetContent: String, AppEnum {
    case countdown, tasks, links
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "展示内容"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [.countdown: "初试倒计时", .tasks: "待办事项", .links: "灵感链接"]
}

struct WidgetDisplay {
    var usesPhoto: Bool
    var records: [WidgetRecord]?
    /// A saved photo replaces a solid theme, including midnight. Records appear once sharing is on;
    /// a countdown widget then shows tasks, or links when there are no tasks.
    static func resolve(theme _: WidgetTheme, content: WidgetContent, snapshot: WidgetSnapshot, photo: Data?) -> WidgetDisplay {
        let records: [WidgetRecord]?
        if content == .countdown && !snapshot.enabled {
            records = nil
        } else if content == .links {
            records = snapshot.links
        } else if content == .countdown && snapshot.tasks.isEmpty {
            records = snapshot.links
        } else {
            records = snapshot.tasks
        }
        return WidgetDisplay(usesPhoto: !(photo ?? Data()).isEmpty, records: records)
    }
}

struct WidgetRecord: Codable, Identifiable {
    var id: UUID
    var title: String
    var detail: String
}

struct WidgetSnapshot: Codable {
    var enabled = false
    var tasks: [WidgetRecord] = []
    var links: [WidgetRecord] = []
}

protocol WidgetSecondaryStore {
    func save(_ data: Data, account: String) -> Bool
    func load(account: String) -> Data?
    func delete(account: String)
}

enum WidgetSnapshotStore {
    static var secondary: any WidgetSecondaryStore = WidgetKeychain()
    static let group = "group.com.yiyun.essaypilot.shared"
    private static let snapshotKey = "widget.snapshot"
    private static let snapshotAccount = "snapshot"
    private static let backgroundAccount = "background"
    private static var groupDefaults: UserDefaults? { UserDefaults(suiteName: group) }
    static var backgroundURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget-background.jpg")
    }
    static func read() -> WidgetSnapshot {
        if let data = groupDefaults?.data(forKey: snapshotKey), let snapshot = decode(data) { return snapshot }
        if let data = secondary.load(account: snapshotAccount), let snapshot = decode(data) { return snapshot }
        return WidgetSnapshot()
    }
    static func readBackground() -> Data? {
        if let url = backgroundURL, let data = try? Data(contentsOf: url), !data.isEmpty { return data }
        return secondary.load(account: backgroundAccount)
    }
    @discardableResult static func write(_ snapshot: WidgetSnapshot) -> Bool {
        guard let data = encode(snapshot) else { return false }
        let groupChanged = groupDefaults?.data(forKey: snapshotKey) != data
        if groupChanged { groupDefaults?.set(data, forKey: snapshotKey) }
        let secondaryChanged = secondary.load(account: snapshotAccount) != data && secondary.save(data, account: snapshotAccount)
        return groupChanged || secondaryChanged
    }
    static func writeBackground(_ data: Data) throws {
        var stored = false
        if let url = backgroundURL {
            try data.write(to: url, options: .atomic)
            stored = true
        }
        if secondary.save(data, account: backgroundAccount) { stored = true }
        if !stored { throw CocoaError(.fileWriteUnknown) }
    }
    static func removeBackground() throws {
        if let url = backgroundURL, FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        secondary.delete(account: backgroundAccount)
    }
    @discardableResult static func replicateBackground() -> Bool {
        guard let data = backgroundURL.flatMap({ try? Data(contentsOf: $0) }), !data.isEmpty else { return false }
        return secondary.load(account: backgroundAccount) != data && secondary.save(data, account: backgroundAccount)
    }
    static func eraseGroupCopies() {
        groupDefaults?.removeObject(forKey: snapshotKey)
        if let url = backgroundURL, FileManager.default.fileExists(atPath: url.path) { try? FileManager.default.removeItem(at: url) }
    }
    static func resetSharedCopies() {
        eraseGroupCopies()
        secondary.delete(account: snapshotAccount)
        secondary.delete(account: backgroundAccount)
    }
    private static func encode(_ snapshot: WidgetSnapshot) -> Data? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(snapshot)
    }
    private static func decode(_ data: Data) -> WidgetSnapshot? { try? JSONDecoder().decode(WidgetSnapshot.self, from: data) }
}

struct WidgetKeychain: WidgetSecondaryStore {
    private static let service = "com.yiyun.essaypilot.widget"
    func save(_ data: Data, account: String) -> Bool {
        if Self.store(data, account: account, group: Self.accessGroup()) { return true }
        return Self.accessGroup() == nil ? false : Self.store(data, account: account, group: nil)
    }
    func load(account: String) -> Data? {
        if let group = Self.accessGroup(), let data = Self.copy(account: account, group: group) { return data }
        return Self.copy(account: account, group: nil)
    }
    func delete(account: String) {
        SecItemDelete(Self.base(account: account, group: Self.accessGroup()) as CFDictionary)
        SecItemDelete(Self.base(account: account, group: nil) as CFDictionary)
    }
    private static func store(_ data: Data, account: String, group: String?) -> Bool {
        let query = base(account: account, group: group)
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
    private static func copy(account: String, group: String?) -> Data? {
        var query = base(account: account, group: group)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }
    private static func base(account: String, group: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let group { query[kSecAttrAccessGroup as String] = group }
        return query
    }
    /// Development profiles allow `TEAMID.*`. The shared item lives in the main app's keychain group.
    static func accessGroup() -> String? {
        let bundle = "com.yiyun.essaypilot.dev"
        if let prefix = provisionPrefix() { return "\(prefix).\(bundle)" }
        return bundle
    }
    private static func provisionPrefix() -> String? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)),
              let plist = try? PropertyListSerialization.propertyList(from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any],
              let prefix = (plist["ApplicationIdentifierPrefix"] as? [String])?.first, !prefix.isEmpty else { return nil }
        return prefix
    }
}
