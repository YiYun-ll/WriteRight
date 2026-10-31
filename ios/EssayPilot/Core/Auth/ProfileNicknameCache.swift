import Foundation

struct ProfileNicknameCache {
    let namespace: String
    var defaults: UserDefaults = .standard
    private func key(_ userID: UUID) -> String { "writeright.nickname.\(ContentFingerprint.hash(namespace)).\(userID.uuidString)" }
    func load(_ userID: UUID) -> String? { Self.normalized(defaults.string(forKey: key(userID))) }
    func save(_ nickname: String?, userID: UUID) { defaults.set(nickname ?? "", forKey: key(userID)) }
    func erase(_ userID: UUID) { defaults.removeObject(forKey: key(userID)) }
    static func normalized(_ value: String?) -> String? {
        let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return clean.isEmpty ? nil : clean
    }
}
