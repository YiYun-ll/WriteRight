import SwiftUI

@main
struct EssayPilotApp: App {
    @StateObject private var model = AppModel()
    @AppStorage("appearance") private var appearance = "system"

    init() { ExamSchedule.publish() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .tint(WriteRightTheme.accent)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                #if DEBUG
                .task { await BackendConnectivityProbe.runIfRequested() }
                #endif
        }
    }
}
