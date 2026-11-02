import Foundation
import WidgetKit

enum ExamSchedule {
    static let appGroup = "group.com.yiyun.essaypilot.shared"
    static let examYear = 2026
    static let examMonth = 12
    static let examDay = 19
    private static let suite = "writeright.exam-date"

    static var examDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let stored = UserDefaults(suiteName: appGroup)?.double(forKey: suite) ?? 0
        if stored > 0 { return Date(timeIntervalSince1970: stored) }
        return calendar.date(from: DateComponents(year: examYear, month: examMonth, day: examDay, hour: 12))!
    }

    static func publish() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(year: examYear, month: examMonth, day: examDay, hour: 12))!
        UserDefaults(suiteName: appGroup)?.set(date.timeIntervalSince1970, forKey: suite)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func daysRemaining(on date: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: examDate)).day ?? 0
    }

    static var dateLine: String {
        examDate.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).year().month().day())
    }
}
