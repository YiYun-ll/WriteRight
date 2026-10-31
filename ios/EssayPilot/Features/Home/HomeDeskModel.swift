import Foundation
import Combine

enum DeskWindow: String, CaseIterable {
    case quiet, breeze, rain
    var title: String { switch self { case .quiet: "窗外安静"; case .breeze: "窗边微风"; case .rain: "窗边小雨" } }
    var symbol: String { switch self { case .quiet: "window.vertical.open"; case .breeze: "wind"; case .rain: "cloud.drizzle" } }
    var response: String {
        switch self {
        case .quiet: "把风雨收起来，听听此刻的安静。"
        case .breeze: "让一点风经过窗边，紧绷的念头也可以松一松。"
        case .rain: "小画里落起了雨。你可以安心坐着，等一句话慢慢来。"
        }
    }
}

/// Illustration states are temporary choices, never weather data or real activity records.
@MainActor final class HomeDeskModel: ObservableObject {
    @Published var lampOn = true
    @Published private(set) var lampGlow: Double = 1
    @Published var resting = false
    @Published var sunsetProgress: Double = 0
    @Published private(set) var window: DeskWindow = .quiet
    @Published private(set) var windowMotion: Double = 0
    @Published private(set) var teaLift: Double = 0
    @Published private(set) var plantPulse: Double = 0
    @Published private(set) var motionRevision = 0
    private(set) var motionDuration: Double = 0.4
    @Published private(set) var response: String?
    func toggleLamp() { lampOn.toggle(); lampGlow = lampOn ? 1 : 0; response = nil; motionDuration = 0.4; motionRevision += 1 }
    func toggleRest() { resting.toggle(); sunsetProgress = resting ? 1 : 0; lampOn = !resting; lampGlow = lampOn ? 1 : 0; response = nil; motionDuration = resting ? 7 : 0.8; motionRevision += 1 }
    func changeWindow() {
        window = window == .quiet ? .breeze : window == .breeze ? .rain : .quiet
        windowMotion += 1; response = window.response; motionDuration = 3; motionRevision += 1
    }
    func pourTea() {
        teaLift += 1; motionDuration = 3; motionRevision += 1
        response = "茶气又慢慢升起来。屏幕外的你，也记得照顾自己。"
    }
    func tendPlant() {
        plantPulse += 1; motionDuration = 3; motionRevision += 1
        response = "叶子轻轻舒展开。小小的绿意，今天也被你照顾到了。"
    }
    func caption(mood: DeskMood) -> String {
        if let response { return response }
        if resting { return lampOn ? "夜色里，给自己留一盏小灯。" : "太阳慢慢落下，今天可以先到这里。" }
        return lampOn ? mood.sceneCaption : "灯歇一会儿，桌子和纸都还在。"
    }
}
