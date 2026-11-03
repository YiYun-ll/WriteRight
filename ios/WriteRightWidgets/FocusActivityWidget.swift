import ActivityKit
import SwiftUI
import WidgetKit

struct FocusActivityWidget: Widget {
    private let islandAccent = Color(red: 1, green: 0.76, blue: 0.49)
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(WriteRightWidgetStyle.accent.opacity(0.10)).frame(width: 48, height: 48)
                    Image(systemName: "book.pages.fill").font(.title2).foregroundStyle(WriteRightWidgetStyle.accent)
                }.accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(context.state.name)陪你写").font(.headline).lineLimit(1)
                    Text("专注此刻，慢慢成篇").font(.caption).foregroundStyle(WriteRightWidgetStyle.secondary)
                    ProgressView(timerInterval: context.attributes.startedAt...max(context.attributes.startedAt, context.state.endsAt), countsDown: false)
                        .tint(WriteRightWidgetStyle.accent).labelsHidden().accessibilityLabel("陪写进度")
                }
                VStack(alignment: .trailing, spacing: 4) {
                    timer(context).font(.system(.title2, design: .rounded).weight(.medium)).frame(width: 92)
                    Text("剩余时间").font(.caption2).foregroundStyle(WriteRightWidgetStyle.secondary)
                }
            }.foregroundStyle(WriteRightWidgetStyle.ink).padding(18)
                .activityBackgroundTint(WriteRightWidgetStyle.paper)
                .activitySystemActionForegroundColor(WriteRightWidgetStyle.accent)
                .widgetURL(URL(string: "writeright://home"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("陪写中", systemImage: "book.pages.fill").font(.subheadline.weight(.medium)).foregroundStyle(islandAccent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(context).font(.system(.title2, design: .rounded).weight(.medium)).frame(width: 100).foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(context.state.name)陪你，一页一页慢慢写。").font(.caption).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                        ProgressView(timerInterval: context.attributes.startedAt...max(context.attributes.startedAt, context.state.endsAt), countsDown: false)
                            .tint(islandAccent).labelsHidden().accessibilityLabel("陪写进度")
                    }.padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "book.pages.fill").foregroundStyle(islandAccent)
            } compactTrailing: {
                timer(context).font(.caption.weight(.medium)).foregroundStyle(islandAccent).frame(width: 54)
            } minimal: {
                Image(systemName: "book.pages.fill").foregroundStyle(islandAccent)
            }
            .keylineTint(islandAccent)
            .widgetURL(URL(string: "writeright://home"))
        }
    }
    private func timer(_ context: ActivityViewContext<FocusActivityAttributes>) -> some View {
        Text(timerInterval: context.attributes.startedAt...max(context.attributes.startedAt, context.state.endsAt), countsDown: true)
            .monospacedDigit().minimumScaleFactor(0.7).lineLimit(1).accessibilityLabel("陪写剩余时间")
    }
}
