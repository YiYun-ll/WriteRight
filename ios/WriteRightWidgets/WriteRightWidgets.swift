import SwiftUI
import WidgetKit

@main
struct WriteRightWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ExamCountdownWidget()
        FocusActivityWidget()
    }
}

private struct ExamEntry: TimelineEntry {
    let date: Date
    let days: Int
}

private struct ExamProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExamEntry { ExamEntry(date: .now, days: 48) }
    func getSnapshot(in context: Context, completion: @escaping (ExamEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ExamEntry>) -> Void) {
        let current = entry()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now.addingTimeInterval(86_400)
        completion(Timeline(entries: [current], policy: .after(tomorrow)))
    }
    private func entry() -> ExamEntry { ExamEntry(date: .now, days: ExamSchedule.daysRemaining(on: .now)) }
}

struct ExamCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WriteRightExamCountdown", provider: ExamProvider()) { entry in
            ExamCountdownView(entry: entry).containerBackground(for: .widget) { WriteRightWidgetStyle.paper }
        }
        .configurationDisplayName("初试倒计时")
        .description("留一页给今天，也看一眼前方的日子。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ExamCountdownView: View {
    let entry: ExamEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        if family == .systemMedium {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    brand
                    Spacer()
                    Text("写过的每一页，都算数。").font(.system(.subheadline, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ExamSchedule.dateLine).font(.caption).foregroundStyle(WriteRightWidgetStyle.secondary)
                }
                Spacer()
                countdown
            }.padding(20)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                brand
                Spacer()
                HStack(alignment: .firstTextBaseline) {
                    countdown
                    Spacer()
                }
                Text(ExamSchedule.dateLine).font(.caption).foregroundStyle(WriteRightWidgetStyle.secondary)
            }.padding(16)
        }
    }
    private var brand: some View {
        Label("WriteRight", systemImage: "checkmark").font(.caption.weight(.semibold))
            .foregroundStyle(WriteRightWidgetStyle.accent)
    }
    @ViewBuilder private var countdown: some View {
        if entry.days > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.days, format: .number).font(.system(size: family == .systemMedium ? 60 : 48, weight: .medium, design: .serif))
                Text("天").font(.title3).foregroundStyle(WriteRightWidgetStyle.secondary)
            }.foregroundStyle(WriteRightWidgetStyle.ink)
        } else if entry.days == 0 {
            Text("初试这一天").font(.system(.title2, design: .serif)).foregroundStyle(WriteRightWidgetStyle.ink)
        } else {
            Text("这一程，辛苦了").font(.system(.title3, design: .serif)).foregroundStyle(WriteRightWidgetStyle.ink)
        }
    }
}

enum WriteRightWidgetStyle {
    static let paper = Color(red: 0.975, green: 0.957, blue: 0.918)
    static let ink = Color(red: 0.19, green: 0.16, blue: 0.13)
    static let secondary = Color(red: 0.43, green: 0.39, blue: 0.34)
    static let accent = Color(red: 0.65, green: 0.25, blue: 0.13)
}
