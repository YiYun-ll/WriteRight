import SwiftUI

struct InteractiveDeskView: View {
    let mood: DeskMood
    let reportCount: Int
    let now: Date
    let daysToExam: Int
    @StateObject private var desk = HomeDeskModel()
    @StateObject private var companion: CompanionModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private var canAnimate: Bool { !reduceMotion && scenePhase == .active }
    private var hour: Int { Calendar.current.component(.hour, from: now) }
    private var night: Bool { desk.resting || hour >= 19 || hour < 5 }
    private var companionContext: CompanionContext {
        CompanionContext(name: companion.state.name, stage: companion.stage(reports: reportCount), hour: hour,
                         resting: desk.resting, lampOn: desk.lampOn, raining: desk.window == .rain, mood: mood,
                         daysToExam: daysToExam, focusing: companion.focusing, returnedAfterDays: companion.returnedAfterDays)
    }

    let companionRevision: Int
    let companionGrew: () -> Void

    init(mood: DeskMood, owner: String, reportCount: Int, now: Date, daysToExam: Int,
         companionRevision: Int = 0, companionGrew: @escaping () -> Void = {}) {
        self.mood = mood; self.reportCount = reportCount; self.now = now; self.daysToExam = daysToExam
        self.companionRevision = companionRevision; self.companionGrew = companionGrew
        _companion = StateObject(wrappedValue: CompanionModel(owner: owner))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                QuietDeskScene(mood: mood, sunsetProgress: desk.sunsetProgress,
                               window: desk.window, windowMotion: desk.windowMotion, teaLift: desk.teaLift, plantPulse: desk.plantPulse, lampGlow: desk.lampGlow)
                    .animation(canAnimate ? .easeInOut(duration: desk.motionDuration) : nil, value: desk.motionRevision)
                CompanionPetCanvas(pose: companion.pose(resting: desk.resting, reports: reportCount),
                                   stage: companion.stage(reports: reportCount), night: night, bounce: companion.bounce)
                    .animation(canAnimate ? .easeOut(duration: 0.7) : nil, value: companion.bounce)
                DeskLightLayer(sunsetProgress: desk.sunsetProgress, lampGlow: desk.lampGlow)
                    .animation(canAnimate ? .easeInOut(duration: desk.motionDuration) : nil, value: desk.motionRevision)
            }
            .frame(height: 170)
            .overlay { GeometryReader { geo in
                let space = DeskSpace(geo.size)
                let feet = CompanionPetCanvas.deskAnchor
                petButton.frame(width: 80 * space.scale, height: 76 * space.scale)
                    .position(space.point(CGPoint(x: feet.x, y: feet.y - 36)))
            } }
            HStack(alignment: .top, spacing: 16) {
                Text(desk.caption(mood: mood)).id(desk.caption(mood: mood))
                    .font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity).accessibilityIdentifier("home-lamp-response")
                Button { desk.toggleLamp() } label: {
                    Image(systemName: desk.lampOn ? "lamp.desk.fill" : "lamp.desk").font(.title3).frame(width: 44, height: 44)
                }.buttonStyle(.plain).foregroundStyle(WriteRightTheme.accent)
                    .accessibilityLabel("书桌的灯").accessibilityValue(desk.lampOn ? "亮着" : "已关")
                    .accessibilityHint("轻点改变书桌的灯光").accessibilityIdentifier("home-lamp")
            }.animation(canAnimate ? .easeInOut(duration: 0.22) : nil, value: desk.caption(mood: mood))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 8) {
                deskButton(desk.window.title, symbol: desk.window.symbol, id: "home-window", value: desk.window.title) { desk.changeWindow() }
                deskButton("添杯热茶", symbol: "cup.and.saucer", id: "home-tea", value: desk.teaLift > 0 ? "茶还温着" : "等你添茶") { desk.pourTea() }
                deskButton("照料绿植", symbol: "leaf", id: "home-plant", value: desk.plantPulse > 0 ? "已照料小画里的绿植" : "窗边的小绿意") { desk.tendPlant() }
            }
            CompanionCard(companion: companion, context: companionContext, reportCount: reportCount)
            Button {
                desk.toggleRest()
            } label: {
                Label(desk.resting ? "回到白天" : "看看日落，歇一会儿", systemImage: desk.resting ? "sunrise" : "sunset")
                    .font(.subheadline).frame(minHeight: 44)
            }.buttonStyle(.plain).foregroundStyle(WriteRightTheme.accent)
                .accessibilityIdentifier("home-rest-mode").accessibilityValue(desk.resting ? "休息模式，夜晚" : "白天")
                .accessibilityHint("切换小画的日落夜景和关灯状态，不改变App外观设置")
        }
        .onAppear { companion.settleFocus(reports: reportCount); companion.recordVisit(now: now, reports: reportCount) }
        .onChange(of: now) { _, value in companion.recordVisit(now: value, reports: reportCount) }
        .onChange(of: reportCount) { _, count in companion.celebrateIfGrown(reports: count) }
        .onChange(of: desk.motionRevision) { _, _ in companion.clearResponse() }
        .onChange(of: mood) { _, _ in companion.clearResponse() }
        .onChange(of: companionRevision) { _, _ in companion.reload() }
        .onChange(of: companion.state.needsUpload) { _, pending in if pending { companionGrew() } }
    }
    private var petButton: some View {
        Button { companion.pat(reports: reportCount) } label: { Color.clear.contentShape(Rectangle()) }
            .buttonStyle(.plain)
            .accessibilityLabel("\(companion.state.name)，\(companion.stage(reports: reportCount).title)")
            .accessibilityHint("轻点摸摸它").accessibilityIdentifier("companion-pet")
    }
    private func deskButton(_ title: String, symbol: String, id: String, value: String, action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 21, weight: .light)).accessibilityHidden(true)
                Text(title).font(.caption).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, minHeight: 64).padding(.vertical, 8)
                .foregroundStyle(WriteRightTheme.accent)
                .background(WriteRightTheme.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(id).accessibilityValue(value)
            .accessibilityHint("只改变这幅小画的状态，不记录真实天气或活动")
    }
}
