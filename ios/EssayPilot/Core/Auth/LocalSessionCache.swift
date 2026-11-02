import Foundation

struct LocalSessionCache {
    let defaults: UserDefaults
    let namespace: String

    private var key: String { LocalOwnerDefaults.key("writeright.last-account", owner: namespace) }

    func load() -> AccountSession? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(AccountSession.self, from: $0) }
    }

    func save(_ session: AccountSession?) {
        if let session, let data = try? JSONEncoder().encode(session) { defaults.set(data, forKey: key) }
        else { defaults.removeObject(forKey: key) }
    }
}
