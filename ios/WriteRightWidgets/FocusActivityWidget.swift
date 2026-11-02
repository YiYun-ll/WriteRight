import ActivityKit
import SwiftUI
import WidgetKit

struct FocusActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            HStack(spacing: 16) {
                Image(systemName: "book.closed.fill").font(.title2).foregroundStyle(WriteRightWidgetStyle.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(context.state.name)陪你写").font(.subheadline).foregroundStyle(WriteRightWidgetStyle.secondary)
                    Text(context.state.endsAt, style: .timer).font(.system(.title2, design: .serif)).monospacedDigit()
                        .foregroundStyle(WriteRightWidgetStyle.ink)
                }
                Spacer()
            }.padding(18).activityBackgroundTint(WriteRightWidgetStyle.paper).activitySystemActionForegroundColor(WriteRightWidgetStyle.accent)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.name, systemImage: "book.closed.fill").font(.subheadline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endsAt, style: .timer).font(.title3).monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("一页一页，慢慢写。").font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "book.closed.fill").foregroundStyle(WriteRightWidgetStyle.accent)
            } compactTrailing: {
                Text(context.state.endsAt, style: .timer).monospacedDigit().frame(maxWidth: 64)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(WriteRightWidgetStyle.accent)
            }
        }
    }
}
