import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: MainTab = .home
    @State private var editing: DraftDocument?

    var body: some View {
        Group {
            if model.isReady {
                TabView(selection: $selection) {
                    NavigationStack {
                        HomeView(onCreate: create, onOpen: open)
                    }.tabItem { Label("首页", systemImage: "square.grid.2x2") }.tag(MainTab.home)
                    NavigationStack {
                        PracticeView(onCreate: create)
                    }.tabItem { Label("练习", systemImage: "square.and.pencil") }.tag(MainTab.practice)
                    NavigationStack {
                        HistoryView(onOpen: open, onCreate: { selection = .practice })
                    }.tabItem { Label("历史", systemImage: "clock") }.tag(MainTab.history)
                    NavigationStack { SettingsView() }
                        .tabItem { Label("我的", systemImage: "person.crop.circle") }.tag(MainTab.profile)
                }
                .fullScreenCover(item: $editing) { document in
                    if let repository = model.repository {
                        EssayEditorView(document: document, repository: repository, didSave: model.refresh)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("练习库未能打开", systemImage: "externaldrive.badge.exclamationmark")
                } description: { Text("原有数据已保留。") } actions: {
                    Button("重试", action: model.openStore).buttonStyle(.borderedProminent)
                }
            }
        }
        .background(WriteRightTheme.background)
        .task { await model.observeAuth() }
        .alert("需要处理", isPresented: Binding(get: { model.isReady && model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("重试", action: model.refresh)
            Button("关闭", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func create(_ part: WritingPart, _ task: WritingTaskDocument? = nil) {
        editing = model.createDraft(part: part, task: task)
    }
    private func open(_ draft: DraftDocument) { editing = draft }
}

enum MainTab { case home, practice, history, profile }
