import SwiftUI

/// The cat's corner beside the desk: what it is saying, how it is growing, and three ways to spend time with it.
struct CompanionCard: View {
    @ObservedObject var companion: CompanionModel
    let context: CompanionContext
    let reportCount: Int
    @State private var showGrowth = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase

    private var stage: CompanionStage { companion.stage(reports: reportCount) }
    private var line: String { companion.line(context) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 10) { title; Spacer(minLength: 8); growthLink }
                VStack(alignment: .leading, spacing: 4) { title; growthLink }
            }
            Text(line)
                .font(.system(.subheadline, design: .serif)).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("companion-line")
            progress
            if let end = companion.state.focusEndsAt { focusRow(end) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 8) {
                action("摸摸头", symbol: "heart", id: "companion-pat") { companion.pat(reports: reportCount) }
                action("喂小鱼干", symbol: "fish", id: "companion-treat") { companion.treat(reports: reportCount) }
                if companion.focusing {
                    action("先到这里", symbol: "checkmark", id: "companion-focus-end") { companion.finishFocus(reports: reportCount) }
                } else {
                    Menu {
                        ForEach([10, 25, 45], id: \.self) { minutes in
                            Button("\(minutes) 分钟") { companion.startFocus(minutes: minutes) }
                        }
                    } label: { actionLabel("陪我写一会儿", symbol: "timer") }
                        .accessibilityIdentifier("companion-focus").accessibilityHint("选择时长，\(companion.state.name)会在书桌边陪你写")
                }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        // Text changes instantly; cross-fading lines of different heights leaves overlapping ghosts.
        .transaction { $0.animation = nil }
        .sheet(isPresented: $showGrowth) { CompanionGrowthView(companion: companion, reportCount: reportCount) }
        .task(id: companion.state.focusEndsAt) {
            guard let end = companion.state.focusEndsAt else { return }
            try? await Task.sleep(nanoseconds: UInt64(max(0, end.timeIntervalSinceNow) * 1_000_000_000))
            if !Task.isCancelled { companion.settleFocus(reports: reportCount) }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { companion.settleFocus(reports: reportCount) } }
    }

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(companion.state.name).font(.system(.title3, design: .serif))
            Text(stage.title).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
        }.accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }
    private var growthLink: some View {
        Button { showGrowth = true } label: {
            HStack(spacing: 4) { Text("成长路线"); Image(systemName: "chevron.right").font(.caption) }
                .font(.subheadline).frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(WriteRightTheme.accent).accessibilityIdentifier("companion-growth")
    }
    private var progress: some View {
        let value = companion.progress(reports: reportCount)
        let caption = value.remaining.map { "再陪 \($0) 点，\(companion.state.name)会成为「\(stage.next?.title ?? "")」" }
            ?? "已经长成「\(stage.title)」，接下来就一起走下去。"
        return VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: value.fraction).tint(WriteRightTheme.accent).accessibilityHidden(true)
            Text(caption).font(.caption).foregroundStyle(WriteRightTheme.secondary).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine).accessibilityIdentifier("companion-progress")
    }
    private func focusRow(_ end: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let left = max(0, Int(end.timeIntervalSince(timeline.date).rounded(.up)))
            HStack(spacing: 10) {
                Image(systemName: "timer").accessibilityHidden(true)
                Text("一起写着").font(.subheadline)
                Spacer(minLength: 8)
                Text(String(format: "%d:%02d", left / 60, left % 60)).font(.system(.title3, design: .serif)).monospacedDigit()
            }.foregroundStyle(WriteRightTheme.accent).padding(.horizontal, 14).frame(minHeight: 44)
                .background(WriteRightTheme.soft.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityElement(children: .combine).accessibilityLabel("一起写着，还剩 \(left / 60) 分 \(left % 60) 秒")
                .accessibilityIdentifier("companion-focus-timer")
        }
    }
    private func action(_ title: String, symbol: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { actionLabel(title, symbol: symbol) }.buttonStyle(.plain).accessibilityIdentifier(id)
    }
    private func actionLabel(_ title: String, symbol: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 19, weight: .light)).accessibilityHidden(true)
            Text(title).font(.caption).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, minHeight: 60).padding(.vertical, 6)
            .foregroundStyle(WriteRightTheme.accent)
            .background(WriteRightTheme.soft.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
    }
}

struct CompanionGrowthView: View {
    @ObservedObject var companion: CompanionModel
    let reportCount: Int
    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var draftName = ""
    private var points: Int { companion.points(reports: reportCount) }
    private var stage: CompanionStage { companion.stage(reports: reportCount) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(spacing: 12) {
                        CompanionPetCanvas(pose: .sitting, stage: stage, night: false, bounce: companion.bounce,
                                           anchor: CGPoint(x: 60, y: 74), canvasSize: CGSize(width: 120, height: 80))
                            .frame(height: 150).frame(maxWidth: .infinity)
                        Text(companion.state.name).font(.system(.title, design: .serif))
                        Text("第 \(stage.rawValue + 1) 阶 · \(stage.title) · \(points) 点").font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                        Button("给它改个名字") { draftName = companion.state.name; renaming = true }
                            .font(.subheadline).frame(minHeight: 44).accessibilityIdentifier("companion-rename")
                    }.frame(maxWidth: .infinity)
                    footprints
                    VStack(alignment: .leading, spacing: 16) {
                        Text("成长路线").font(.system(.title3, design: .serif)).accessibilityAddTraits(.isHeader)
                        ForEach(CompanionStage.allCases) { item in stageRow(item) }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("怎样一起长大").font(.system(.title3, design: .serif)).accessibilityAddTraits(.isHeader)
                        rule("每天第一次来书桌坐坐", "+\(CompanionState.Rule.visit)")
                        rule("摸摸它（每天计一次）", "+\(CompanionState.Rule.pat)")
                        rule("喂一条小鱼干（每天计一次）", "+\(CompanionState.Rule.treat)")
                        rule("陪写每 \(CompanionState.Rule.focusMinutesPerPoint) 分钟", "+1")
                        rule("每收到一份批改报告", "+\(CompanionState.Rule.report)")
                    }
                    Text("\(companion.state.name)不会因为你几天没来而难过，成长也不会倒退；它只记得你来过。登录后，名字、来访日期和陪写分钟会随账号同步，换手机也能接着长大；未登录时只留在这台设备上。这些记录不发送给 AI。")
                        .font(.footnote).foregroundStyle(WriteRightTheme.secondary).lineSpacing(4)
                }.padding(24)
            }
            .background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
            .navigationTitle("\(companion.state.name)的成长").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("好") { dismiss() }.accessibilityIdentifier("companion-growth-done") } }
            .alert("给它起个名字", isPresented: $renaming) {
                TextField("最多 8 个字", text: $draftName)
                Button("就叫这个") { companion.rename(draftName) }
                Button("取消", role: .cancel) {}
            } message: { Text("留空会恢复「\(CompanionState.defaultName)」。") }
        }
    }
    private var footprints: some View {
        let state = companion.state
        let items = [("相识", state.metAt.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).month().day())),
                     ("来书桌", "\(state.visitDays) 天"), ("一起写了", "\(state.focusMinutes) 分钟"), ("批改报告", "\(reportCount) 份")]
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], alignment: .leading, spacing: 12) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0).font(.caption).foregroundStyle(WriteRightTheme.secondary)
                    Text(item.1).font(.system(.headline, design: .serif)).monospacedDigit()
                }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityElement(children: .combine)
            }
        }
    }
    private func stageRow(_ item: CompanionStage) -> some View {
        let reached = item <= stage
        let isNext = item == stage.next
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(reached ? WriteRightTheme.accent : Color.clear)
                Circle().strokeBorder(WriteRightTheme.accent.opacity(reached || isNext ? 0.9 : 0.35), lineWidth: 1.5)
            }.frame(width: 14, height: 14).padding(.top, 5).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title).font(.system(.headline, design: .serif))
                    Spacer(minLength: 8)
                    Text(reached ? "已经走到" : "\(item.threshold) 点").font(.caption).foregroundStyle(WriteRightTheme.secondary).monospacedDigit()
                }
                Text(item.unlock).font(.subheadline).foregroundStyle(WriteRightTheme.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.opacity(reached || isNext ? 1 : 0.6)
            .accessibilityElement(children: .combine)
            .accessibilityValue(reached ? "已经走到" : isNext ? "下一阶，还差 \(item.threshold - points) 点" : "需要 \(item.threshold) 点")
    }
    private func rule(_ title: String, _ value: String) -> some View {
        HStack { Text(title).font(.subheadline); Spacer(); Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(WriteRightTheme.accent) }
            .accessibilityElement(children: .combine)
    }
}
