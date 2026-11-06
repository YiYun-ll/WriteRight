import AppIntents
import Foundation
import Security
import SwiftUI
import UIKit

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

struct WidgetRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var detail: String
}

struct WidgetSnapshot: Codable {
    var enabled = false
    var tasks: [WidgetRecord] = []
    var links: [WidgetRecord] = []
    var updatedAt: Date? = nil
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
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget-background-v2.json")
    }
    private struct Background: Codable {
        var data: Data?
        var updatedAt: Date
    }
    private static var legacyBackgroundURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget-background.jpg")
    }
    static func read() -> WidgetSnapshot {
        let candidates = [groupDefaults?.data(forKey: snapshotKey), secondary.load(account: snapshotAccount)]
            .compactMap { $0.flatMap(decode) }
        return candidates.sorted {
            if $0.updatedAt != $1.updatedAt { return ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
            return !$0.enabled && $1.enabled
        }.first ?? WidgetSnapshot()
    }
    private static func background() -> Background? {
        let candidates = [backgroundURL.flatMap { try? Data(contentsOf: $0) }, secondary.load(account: backgroundAccount), legacyBackgroundURL.flatMap { try? Data(contentsOf: $0) }]
        return candidates.compactMap { data -> Background? in
            guard let data else { return nil }
            if let record = try? JSONDecoder().decode(Background.self, from: data) {
                if let photo = record.data, WidgetPhoto.image(photo) == nil { return nil }
                return record
            }
            return WidgetPhoto.image(data) == nil ? nil : Background(data: data, updatedAt: .distantPast)
        }.max { $0.updatedAt < $1.updatedAt }
    }
    static func readBackground() -> Data? { background()?.data }
    static func readBackgroundImage() -> UIImage? { background()?.data.flatMap(WidgetPhoto.image) }
    @discardableResult static func write(_ snapshot: WidgetSnapshot) -> Bool {
        var snapshot = snapshot
        let current = read()
        snapshot.updatedAt = current.enabled == snapshot.enabled && current.tasks == snapshot.tasks && current.links == snapshot.links ? current.updatedAt : .now
        guard let data = encode(snapshot) else { return false }
        let groupChanged = groupDefaults?.data(forKey: snapshotKey) != data
        if groupChanged { groupDefaults?.set(data, forKey: snapshotKey) }
        let secondaryChanged = secondary.load(account: snapshotAccount) != data && secondary.save(data, account: snapshotAccount)
        return groupChanged || secondaryChanged
    }
    private static func storeBackground(_ record: Background) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(record)
        var stored = false
        if let url = backgroundURL {
            do {
                try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                stored = true
            } catch { /* Re-signing can leave only one shared storage route available. */ }
        }
        if secondary.save(data, account: backgroundAccount) { stored = true }
        if !stored { throw WidgetStorageError.sharedAccessUnavailable }
    }
    static func writeBackground(_ data: Data) throws {
        try storeBackground(.init(data: WidgetPhoto.normalized(data), updatedAt: .now))
    }
    static func removeBackground() throws {
        // A small dated tombstone prevents an inaccessible stale copy from restoring a photo.
        try storeBackground(.init(data: nil, updatedAt: .now))
        if let url = legacyBackgroundURL { try? FileManager.default.removeItem(at: url) }
    }
    @discardableResult static func replicateBackground() -> Bool {
        guard var record = background() else { return false }
        if record.updatedAt == .distantPast, let photo = record.data {
            guard let normalized = try? WidgetPhoto.normalized(photo) else { return false }
            record.data = normalized; record.updatedAt = .now
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(record) else { return false }
        return secondary.load(account: backgroundAccount) != data && secondary.save(data, account: backgroundAccount)
    }
    static func eraseGroupCopies() {
        groupDefaults?.removeObject(forKey: snapshotKey)
        for url in [backgroundURL, legacyBackgroundURL].compactMap({ $0 }) { try? FileManager.default.removeItem(at: url) }
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
        Self.store(data, account: account, group: Self.accessGroup())
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
        let updated = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updated == errSecSuccess { return true }
        guard updated == errSecItemNotFound else { return false }
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
