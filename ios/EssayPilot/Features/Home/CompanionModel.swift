import Foundation
import Combine

/// The desk cat for one local owner (account or guest). Never sent to AI. Signed-in growth is merged
/// with the account's copy by `CompanionSync`; guests keep theirs on this device.
@MainActor final class CompanionModel: ObservableObject {
    @Published private(set) var state: CompanionState
    @Published private(set) var response: String?
    /// Counts taps so the illustration can play one hop per tap; not persisted.
    @Published private(set) var bounce: Double = 0
    @Published private(set) var awake = false
    @Published private(set) var returnedAfterDays = 0
    private let store: CompanionStore
    private let owner: String
    private let calendar: Calendar
    private let deviceID: String
    private let activity: any FocusActivityControlling
    private var patCount = 0

    init(owner: String, defaults: UserDefaults = .standard, calendar: Calendar = .current, now: Date = .now,
         deviceID: String? = nil, activity: any FocusActivityControlling = FocusActivityController.shared) {
        store = CompanionStore(defaults: defaults); self.owner = owner; self.calendar = calendar
        self.deviceID = deviceID ?? CompanionDevice.id(defaults: defaults)
        self.activity = activity
        state = store.load(owner: owner) ?? CompanionState(metAt: now)
        if let startedAt = state.focusStartedAt, let endsAt = state.focusEndsAt {
            activity.start(name: state.name, startedAt: startedAt, endsAt: endsAt)
        }
    }

    var focusing: Bool { state.focusEndsAt != nil }
    func points(reports: Int) -> Int { state.points(reports: reports) }
    func stage(reports: Int) -> CompanionStage { .stage(points: points(reports: reports)) }
    func pose(resting: Bool, reports: Int) -> CompanionPose {
        if focusing { return .focusing }
        if resting || (stage(reports: reports) == .kitten && !awake) { return .sleeping }
        return .sitting
    }
    /// Fraction toward the next stage and the points still needed; nil remaining once fully grown.
    func progress(reports: Int) -> (fraction: Double, remaining: Int?) {
        let points = points(reports: reports), current = CompanionStage.stage(points: points)
        guard let next = current.next else { return (1, nil) }
        let span = Double(next.threshold - current.threshold)
        return (min(1, Double(points - current.threshold) / span), next.threshold - points)
    }

    /// The first visit of a day counts once. Being away is never penalised; the cat just says welcome back.
    func recordVisit(now: Date = .now, reports: Int) {
        let today = CompanionState.dayKey(now, calendar: calendar)
        guard !state.growth.visitDays.contains(today) else { return }
        if let last = state.growth.visitDays.filter({ $0 < today }).max(), let lastDate = Self.date(last, calendar: calendar) {
            returnedAfterDays = calendar.dateComponents([.day], from: lastDate, to: calendar.startOfDay(for: now)).day ?? 0
        }
        state.growth.visitDays.insert(today)
        persist(grew: true); celebrateIfGrown(reports: reports)
    }
    func pat(now: Date = .now, reports: Int) {
        awake = true; bounce += 1; patCount += 1
        response = CompanionVoice.pat(state.name, count: patCount - 1)
        let today = CompanionState.dayKey(now, calendar: calendar)
        if state.growth.patDays.insert(today).inserted { persist(grew: true); celebrateIfGrown(reports: reports) }
    }
    func treat(now: Date = .now, reports: Int) {
        awake = true; bounce += 1
        let today = CompanionState.dayKey(now, calendar: calendar)
        guard state.growth.treatDays.insert(today).inserted else {
            response = "\(state.name)摸摸圆圆的肚子：今天已经吃过啦，留一条明天再吃。"; return
        }
        response = "\(state.name)叼走一条小鱼干，开心地晃了晃尾巴。"
        persist(grew: true); celebrateIfGrown(reports: reports)
    }
    func startFocus(minutes: Int, now: Date = .now) {
        guard !focusing, (1...120).contains(minutes) else { return }
        awake = true
        state.focusStartedAt = now; state.focusEndsAt = now.addingTimeInterval(TimeInterval(minutes * 60))
        response = "好，\(state.name)陪你写 \(minutes) 分钟。不用写得完美，写下去就好。"
        persist(grew: false)
        activity.start(name: state.name, startedAt: now, endsAt: state.focusEndsAt!)
    }
    /// Ending early still counts the minutes already spent together.
    func finishFocus(now: Date = .now, reports: Int) {
        guard let start = state.focusStartedAt, let end = state.focusEndsAt else { return }
        let minutes = max(0, Int(min(now, end).timeIntervalSince(start) / 60))
        state.focusStartedAt = nil; state.focusEndsAt = nil
        activity.finish(name: state.name, endsAt: end)
        if minutes > 0 {
            state.growth.focusMinutes[deviceID, default: 0] += minutes
            state.growth.focusSessions[deviceID, default: 0] += 1
        }
        bounce += 1
        response = now >= end ? "\(minutes) 分钟到啦。\(state.name)伸了个懒腰：我们一起写完了这一段。"
            : minutes > 0 ? "先到这里也很好。\(state.name)记下了你们一起写的 \(minutes) 分钟。" : "没关系，\(state.name)随时可以再陪你。"
        persist(grew: minutes > 0); celebrateIfGrown(reports: reports)
    }
    /// A session that ended while the app was away is credited when the desk is opened again.
    func settleFocus(now: Date = .now, reports: Int) {
        if let end = state.focusEndsAt, now >= end { finishFocus(now: now, reports: reports) }
    }
    func rename(_ value: String, now: Date = .now) {
        state.growth.name = CompanionState.cleanName(value); state.growth.nameUpdatedAt = now
        response = "以后就叫它「\(state.name)」吧。"; persist(grew: true)
    }
    /// Report counts come from real grading results, so growth can happen between visits.
    func celebrateIfGrown(reports: Int) {
        let stage = stage(reports: reports)
        guard stage.rawValue > state.growth.celebratedStage else { return }
        state.growth.celebratedStage = stage.rawValue; awake = true
        response = CompanionVoice.grew(state.name, to: stage); persist(grew: true)
    }
    /// Picks up growth merged from the account on another device.
    func reload() {
        guard let saved = store.load(owner: owner), saved != state else { return }
        state = saved
    }
    func line(_ context: CompanionContext) -> String { response ?? CompanionVoice.line(context) }
    func clearResponse() { response = nil }

    static func erase(owner: String, defaults: UserDefaults = .standard) {
        CompanionStore(defaults: defaults).erase(owner: owner)
    }
    private func persist(grew: Bool) {
        // Another device's growth may have been merged in since this model loaded.
        if let saved = store.load(owner: owner) { state.growth = saved.growth.merged(with: state.growth) }
        if grew { state.needsUpload = true }
        store.save(state, owner: owner)
    }
    private static func date(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// Where each owner's cat lives on this device.
struct CompanionStore {
    var defaults: UserDefaults = .standard
    func load(owner: String) -> CompanionState? {
        defaults.data(forKey: key(owner)).flatMap { try? JSONDecoder().decode(CompanionState.self, from: $0) }
    }
    func save(_ state: CompanionState, owner: String) {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key(owner)) }
    }
    func erase(owner: String) { defaults.removeObject(forKey: key(owner)) }
    private func key(_ owner: String) -> String { LocalOwnerDefaults.key("writeright.companion.v2", owner: owner) }
}

/// A random install identifier so focus minutes from two phones add up instead of overwriting each other.
enum CompanionDevice {
    static func id(defaults: UserDefaults = .standard) -> String {
        let key = "writeright.device-id"
        if let saved = defaults.string(forKey: key), !saved.isEmpty { return saved }
        let value = UUID().uuidString.lowercased()
        defaults.set(value, forKey: key)
        return value
    }
}

/// UserDefaults keys per local owner; UI tests get their own namespace so they never touch everyday data.
enum LocalOwnerDefaults {
    static func key(_ prefix: String, owner: String) -> String {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-ui-test-store"), args.indices.contains(index + 1) {
            return "\(prefix).\(args[index + 1]).\(owner)"
        }
        #endif
        return "\(prefix).\(owner)"
    }
}

/// The retired home-page note. Read only so it can be moved into the notebook or discarded by the user.
enum LegacyDeskNote {
    static func load(owner: String, defaults: UserDefaults = .standard) -> String? {
        let note = defaults.string(forKey: LocalOwnerDefaults.key("writeright.desk-note", owner: owner))?.trimmingCharacters(in: .whitespacesAndNewlines)
        return note?.isEmpty == false ? note : nil
    }
    static func erase(owner: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: LocalOwnerDefaults.key("writeright.desk-note", owner: owner))
    }
}
