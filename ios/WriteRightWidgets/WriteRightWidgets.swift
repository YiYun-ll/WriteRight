import AppIntents
import SwiftUI
import WidgetKit

@main
struct WriteRightWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ExamCountdownWidget()
        FocusActivityWidget()
    }
}

struct DeskWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "自定义 WriteRight"
    static var description = IntentDescription("选择展示内容与背景。")
    @Parameter(title: "展示内容", default: .countdown) var content: WidgetContent
    @Parameter(title: "背景", default: .paper) var theme: WidgetTheme
}

struct DeskEntry: TimelineEntry {
    var date: Date
    var configuration: DeskWidgetIntent
    var snapshot: WidgetSnapshot
}

struct DeskProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DeskEntry { DeskEntry(date: .now, configuration: DeskWidgetIntent(), snapshot: WidgetSnapshot()) }
    func snapshot(for configuration: DeskWidgetIntent, in context: Context) async -> DeskEntry { entry(configuration) }
    func timeline(for configuration: DeskWidgetIntent, in context: Context) async -> Timeline<DeskEntry> {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now.addingTimeInterval(86_400)
        return Timeline(entries: [entry(configuration)], policy: .after(tomorrow))
    }
    private func entry(_ configuration: DeskWidgetIntent) -> DeskEntry {
        DeskEntry(date: .now, configuration: configuration, snapshot: WidgetSnapshotStore.read())
    }
}

struct ExamCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WriteRightExamCountdown", intent: DeskWidgetIntent.self, provider: DeskProvider()) { entry in
            DeskWidgetView(entry: entry).containerBackground(for: .widget) {
                if let image = DeskWidgetView.backgroundImage {
                    ZStack {
                        Image(uiImage: image).resizable().scaledToFill()
                        Color.black.opacity(0.62)
                    }
                } else { entry.configuration.theme.background }
            }
        }
        .configurationDisplayName("WriteRight")
        .description("初试倒计时、待办事项与灵感链接，自由选择背景。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DeskWidgetView: View {
    let entry: DeskEntry
    @Environment(\.widgetFamily) private var family
    static var backgroundImage: UIImage? {
        guard let data = WidgetSnapshotStore.readBackground() else { return nil }
        return UIImage(data: data)
    }
    private var display: WidgetDisplay {
        WidgetDisplay.resolve(theme: entry.configuration.theme, content: entry.configuration.content, snapshot: entry.snapshot, photo: WidgetSnapshotStore.readBackground())
    }
    private var theme: WidgetTheme { display.usesPhoto && Self.backgroundImage != nil ? .photo : entry.configuration.theme }
    private var countdown: Bool { display.records == nil }
    private var showsLinks: Bool {
        entry.configuration.content == .links || (entry.configuration.content == .countdown && entry.snapshot.tasks.isEmpty && !entry.snapshot.links.isEmpty)
    }
    private var title: String { showsLinks ? "灵感链接" : "待办事项" }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(countdown ? "WriteRight" : title).font(countdown ? .custom("TimesNewRomanPS-BoldMT", size: 17, relativeTo: .headline) : .headline)
                Spacer(minLength: 4)
                Image(systemName: countdown ? "calendar" : showsLinks ? "link" : "checklist").font(.subheadline)
            }.foregroundStyle(theme.accent)
            if countdown { countdownBody } else { recordsBody }
        }.foregroundStyle(theme.ink)
            .widgetURL(URL(string: countdown ? "writeright://home" : "writeright://records"))
    }
    private var countdownBody: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Spacer(minLength: 0)
                let days = ExamSchedule.daysRemaining(on: entry.date)
                if days > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(days, format: .number).font(.system(size: 54, weight: .medium, design: .serif)).minimumScaleFactor(0.65)
                        Text("天").font(.callout).foregroundStyle(theme.secondary)
                    }.accessibilityElement(children: .ignore).accessibilityLabel("距初试还有\(days)天")
                } else { Text(days == 0 ? "初试这一天" : "这一程，辛苦了").font(.title3) }
                Text(ExamSchedule.dateLine).font(.caption2).foregroundStyle(theme.secondary)
            }
            if family == .systemMedium {
                Spacer(minLength: 16)
                Text("写过的每一页，\n都算数。").font(.system(.body, design: .serif)).lineSpacing(5).padding(.bottom, 6)
            }
        }
    }
    @ViewBuilder private var recordsBody: some View {
        let records = display.records ?? []
        if !entry.snapshot.enabled {
            Spacer(minLength: 0)
            Text("前往 App 开启记录展示").font(.subheadline)
            Text("我的 · 桌面小组件").font(.caption).foregroundStyle(theme.secondary)
        } else if records.isEmpty {
            Spacer(minLength: 0)
            Text(showsLinks ? "还没有灵感链接" : "暂时没有待办").font(.subheadline)
            Text("点此记下一件事").font(.caption).foregroundStyle(theme.secondary)
        } else {
            ForEach(Array(records.prefix(family == .systemSmall ? 2 : 3))) { record in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: showsLinks ? "link" : "circle").font(.caption).foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.title).font(.subheadline).lineLimit(1)
                        if family == .systemMedium && !record.detail.isEmpty { Text(record.detail).font(.caption2).foregroundStyle(theme.secondary).lineLimit(1) }
                    }
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

enum WriteRightWidgetStyle {
    static let paper = Color(red: 0.975, green: 0.957, blue: 0.918)
    static let ink = Color(red: 0.19, green: 0.16, blue: 0.13)
    static let secondary = Color(red: 0.43, green: 0.39, blue: 0.34)
    static let accent = Color(red: 0.65, green: 0.25, blue: 0.13)
}
