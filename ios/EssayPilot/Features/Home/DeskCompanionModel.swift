import Foundation
import Combine

/// A single private note, scoped to the current local owner. Never sent for grading or sync.
@MainActor final class DeskCompanionModel: ObservableObject {
    @Published var note: String { didSet { defaults.set(String(note.prefix(280)), forKey: key) } }
    private let defaults: UserDefaults
    private let key: String
    init(owner: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults; key = Self.key(owner)
        note = defaults.string(forKey: key) ?? ""
    }
    func clear() { note = ""; defaults.removeObject(forKey: key) }
    static func erase(owner: String, defaults: UserDefaults = .standard) { defaults.removeObject(forKey: key(owner)) }
    private static func key(_ owner: String) -> String {
        let args = ProcessInfo.processInfo.arguments
        #if DEBUG
        if let index = args.firstIndex(of: "-ui-test-store"), args.indices.contains(index + 1) {
            return "writeright.desk-note.\(args[index + 1]).\(owner)"
        }
        #endif
        return "writeright.desk-note.\(owner)"
    }
}
