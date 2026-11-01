import Foundation
import Combine

/// The desk cat for one local owner (account or guest). Kept on this device only; never sent to AI or synced.
@MainActor final class CompanionModel: ObservableObject {
    @Published private(set) var state: CompanionState
    @Published private(set) var response: String?
    /// Counts taps so the illustration can play one hop per tap; not persisted.
    @Published private(set) var bounce: Double = 0
    @Published private(set) var awake = false
    @Published private(set) var returnedAfterDays = 0
    private let defaults: UserDefaults
    private let key: String
    private let calendar: Calendar
    private var patCount = 0

    init(owner: String, defaults: UserDefaults = .standard, calendar: Calendar = .current, now: Date = .now) {
        self.defaults = defaults; self.calendar = calendar; key = LocalOwnerDefaults.key("writeright.companion", owner: owner)
        if let data = defaults.data(forKey: key), let saved = try? JSONDecoder().decode(CompanionState.self, from: data) {
            state = saved
        } else {
            state = CompanionState(metAt: now)
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
        guard state.lastVisitDay != today else { return }
        if let last = state.lastVisitDay, let lastDate = Self.date(last, calendar: calendar) {
            returnedAfterDays = calendar.dateComponents([.day], from: lastDate, to: calendar.startOfDay(for: now)).day ?? 0
        }
        state.visitDays += 1; state.lastVisitDay = today
        persist(); celebrateIfGrown(reports: reports)
    }
    func pat(now: Date = .now, reports: Int) {
        awake = true; bounce += 1; patCount += 1
        response = CompanionVoice.pat(state.name, count: patCount - 1)
        let today = CompanionState.dayKey(now, calendar: calendar)
        if state.lastPatDay != today { state.patDays += 1; state.lastPatDay = today; persist(); celebrateIfGrown(reports: reports) }
    }
    func treat(now: Date = .now, reports: Int) {
        awake = true; bounce += 1
        let today = CompanionState.dayKey(now, calendar: calendar)
        guard state.lastTreatDay != today else {
            response = "\(state.name)摸摸圆圆的肚子：今天已经吃过啦，留一条明天再吃。"; return
        }
        state.treatDays += 1; state.lastTreatDay = today
        response = "\(state.name)叼走一条小鱼干，开心地晃了晃尾巴。"
        persist(); celebrateIfGrown(reports: reports)
    }
    func startFocus(minutes: Int, now: Date = .now) {
        guard !focusing, (1...120).contains(minutes) else { return }
        awake = true
        state.focusStartedAt = now; state.focusEndsAt = now.addingTimeInterval(TimeInterval(minutes * 60))
        response = "好，\(state.name)陪你写 \(minutes) 分钟。不用写得完美，写下去就好。"
        persist()
    }
    /// Ending early still counts the minutes already spent together.
    func finishFocus(now: Date = .now, reports: Int) {
        guard let start = state.focusStartedAt, let end = state.focusEndsAt else { return }
        let minutes = max(0, Int(min(now, end).timeIntervalSince(start) / 60))
        state.focusStartedAt = nil; state.focusEndsAt = nil
        if minutes > 0 { state.focusMinutes += minutes; state.focusSessions += 1 }
        bounce += 1
        response = now >= end ? "\(minutes) 分钟到啦。\(state.name)伸了个懒腰：我们一起写完了这一段。"
            : minutes > 0 ? "先到这里也很好。\(state.name)记下了你们一起写的 \(minutes) 分钟。" : "没关系，\(state.name)随时可以再陪你。"
        persist(); celebrateIfGrown(reports: reports)
    }
    /// A session that ended while the app was away is credited when the desk is opened again.
    func settleFocus(now: Date = .now, reports: Int) {
        if let end = state.focusEndsAt, now >= end { finishFocus(now: now, reports: reports) }
    }
    func rename(_ value: String) {
        state.name = CompanionState.cleanName(value); response = "以后就叫它「\(state.name)」吧。"; persist()
    }
    /// Report counts come from real grading results, so growth can happen between visits.
    func celebrateIfGrown(reports: Int) {
        let stage = stage(reports: reports)
        guard stage.rawValue > state.celebratedStage else { return }
        state.celebratedStage = stage.rawValue; awake = true
        response = CompanionVoice.grew(state.name, to: stage); persist()
    }
    func line(_ context: CompanionContext) -> String { response ?? CompanionVoice.line(context) }
    func clearResponse() { response = nil }

    static func erase(owner: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: LocalOwnerDefaults.key("writeright.companion", owner: owner))
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: key) }
    }
    private static func date(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
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
