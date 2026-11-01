import Foundation

/// The desk cat grows from presence and real practice. Growth never decays and there is no streak to lose.
enum CompanionStage: Int, CaseIterable, Comparable, Identifiable, Sendable {
    case kitten, visitor, guardian, partner, lantern, together
    var id: Int { rawValue }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    var threshold: Int { [0, 12, 32, 64, 108, 168][rawValue] }
    var title: String { ["小毛团", "窗台小客", "书页守护", "陪写伙伴", "长夜灯伴", "同行到初试"][rawValue] }
    var unlock: String {
        switch self {
        case .kitten: "刚来到书桌边，蜷成一团打盹，还有点怕生。"
        case .visitor: "敢坐起来看你写字了，尾巴会轻轻摆。"
        case .guardian: "系上一条柿橙色小围巾，替你守着摊开的书页。"
        case .partner: "抱来一支小铅笔，你写字时，它也在本子边认真比划。"
        case .lantern: "天黑以后会提一盏小灯笼，陪你把最后一句写完。"
        case .together: "背上小书包，准备好和你一起走到考场门口。"
        }
    }
    var next: CompanionStage? { CompanionStage(rawValue: rawValue + 1) }
    static func stage(points: Int) -> CompanionStage { allCases.last { points >= $0.threshold } ?? .kitten }
}

struct CompanionState: Codable, Equatable, Sendable {
    static let defaultName = "团团"
    var name = CompanionState.defaultName
    var metAt: Date
    var visitDays = 0
    var lastVisitDay: String?
    var patDays = 0
    var lastPatDay: String?
    var treatDays = 0
    var lastTreatDay: String?
    var focusMinutes = 0
    var focusSessions = 0
    var focusStartedAt: Date?
    var focusEndsAt: Date?
    var celebratedStage = 0

    enum Rule {
        static let visit = 2, pat = 1, treat = 1, focusMinutesPerPoint = 5, report = 4
    }
    func points(reports: Int) -> Int {
        visitDays * Rule.visit + patDays * Rule.pat + treatDays * Rule.treat
            + focusMinutes / Rule.focusMinutesPerPoint + max(0, reports) * Rule.report
    }
    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    static func cleanName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isNewline && !($0.unicodeScalars.first.map { CharacterSet.controlCharacters.contains($0) } ?? false) }
        return trimmed.isEmpty ? defaultName : String(trimmed.prefix(8))
    }
}

enum CompanionPose: Equatable, Sendable { case sleeping, sitting, focusing }

/// Everything the cat can notice on the desk. Only illustration state and the clock; no real weather or tracking.
struct CompanionContext: Sendable {
    var name: String
    var stage: CompanionStage
    var hour: Int
    var resting = false
    var lampOn = true
    var raining = false
    var mood: DeskMood = .ready
    var daysToExam: Int = 30
    var focusing = false
    var returnedAfterDays = 0
}

enum CompanionVoice {
    static func line(_ c: CompanionContext) -> String {
        let n = c.name
        if c.focusing { return "\(n)趴在本子边，安安静静陪你写。写到哪里都算数。" }
        if c.resting { return "\(n)在窗台蜷成一团，跟着太阳一起歇下了。" }
        if (0..<5).contains(c.hour) { return "这么晚了，\(n)还陪着你。写完这一句，也记得去睡觉。" }
        if c.returnedAfterDays >= 2 { return "你回来啦。\(n)一直在窗边，没有走远。" }
        if c.daysToExam == 0 { return "今天\(n)也背好了小书包。你已经准备了很久，去吧。" }
        if (1...7).contains(c.daysToExam) { return "还有 \(c.daysToExam) 天。\(n)把爪子按在你的本子上：一页一页来。" }
        if !c.lampOn { return "灯关了，\(n)眯起眼睛，也陪你歇一会儿。" }
        if c.raining { return "\(n)看着窗外的雨，尾巴一下一下地数雨点。" }
        switch c.mood {
        case .tired: return "\(n)把脑袋靠过来：累了就歇一会儿，我在这儿。"
        case .unsettled: return "\(n)挨着你坐下，呼噜呼噜。心乱的时候，先听听这个声音。"
        case .ready: break
        }
        if c.stage == .kitten { return "\(n)还有点怕生，蜷在桌角偷偷看你。轻点它，打个招呼吧。" }
        switch c.hour {
        case 5..<11: return "早上好。\(n)伸了个懒腰，等你翻开今天这一页。"
        case 11..<14: return "\(n)在窗台晒太阳。午后不着急，慢慢来。"
        case 14..<18: return "\(n)蹲在书页旁，看你一个词一个词地写。"
        default: return "晚上好。\(n)把灯下最暖的位置留给了你。"
        }
    }
    static func pat(_ name: String, count: Int) -> String {
        let lines = ["\(name)眯起眼睛，发出小小的呼噜声。", "\(name)用脑袋蹭了蹭你的手指。",
                     "\(name)翻了个身，露出软软的肚子。", "\(name)轻轻“喵”了一声，好像在说：你今天也很努力。"]
        return lines[abs(count) % lines.count]
    }
    static func grew(_ name: String, to stage: CompanionStage) -> String {
        "\(name)长大了一点，成了「\(stage.title)」。\(stage.unlock)"
    }
}
