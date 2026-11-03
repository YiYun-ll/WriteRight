import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: MainTab = .home
    @State private var presented: PresentedScreen?

    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-ui-test-tab"), args.indices.contains(index + 1) {
            let tabs: [String: MainTab] = ["home": .home, "practice": .practice, "history": .records, "records": .records, "profile": .profile]
            _selection = State(initialValue: tabs[args[index + 1]] ?? .home)
        }
        #endif
    }

    var body: some View {
        Group {
            if model.isReady {
                TabView(selection: $selection) {
                    NavigationStack {
                        HomeView()
                    }.tabItem { Label("首页", systemImage: "square.grid.2x2") }.tag(MainTab.home)
                    NavigationStack {
                        PracticeView(onPhotos: { presented = .photos(nil) }, onCreate: create, onOpen: open, onOpenReport: { presented = .report($0) })
                    }.tabItem { Label("练习", systemImage: "square.and.pencil") }.tag(MainTab.practice)
                    NavigationStack {
                        NotebookView()
                    }.tabItem { Label("记录", systemImage: "list.bullet.clipboard") }.tag(MainTab.records)
                    NavigationStack { SettingsView(onOpen: open, onPractice: { selection = .practice }) }
                        .tabItem { Label("我的", systemImage: "person.crop.circle") }.tag(MainTab.profile)
                }
                .fullScreenCover(item: $presented) { screen in
                    switch screen {
                    case .editor(let document):
                        if let repository = model.repository {
                            EssayEditorView(document: document, repository: repository, didSave: model.refresh, onPhotos: { presented = .photos(nil) })
                        }
                    case .photos(let draft): PhotoPracticeView(app: model, draft: draft)
                    case .report(let document):
                        GradingReportView(document: document)
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
        .onOpenURL { url in
            guard url.scheme == "writeright" else { return }
            if url.host == "records" { presented = nil; selection = .records }
            else if url.host == "home" { presented = nil; selection = .home }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refreshActiveGradingJobs() } } }
        .onChange(of: model.account?.userID) { old, _ in
            if old == nil, case .photos = presented { return }
            presented = nil
        }
        .alert("需要处理", isPresented: Binding(get: { model.isReady && model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("关闭", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func create(_ part: WritingPart, _ task: WritingTaskDocument? = nil) {
        if let task, !(task.sourcePages ?? []).isEmpty && task.prompt.isEmpty {
            let draft = DraftDocument(id: UUID(), task: task, body: "", source: "photos", transcriptionConfirmed: false, createdAt: .now, updatedAt: .now)
            presented = .photos(draft)
        } else if let draft = model.createDraft(part: part, task: task) { presented = .editor(draft) }
    }
    private func open(_ draft: DraftDocument) { presented = draft.source == "photos" ? .photos(draft) : .editor(draft) }
}

enum MainTab { case home, practice, records, profile }

private enum PresentedScreen: Identifiable {
    case editor(DraftDocument), report(GradingReportDocument), photos(DraftDocument?)
    var id: String {
        switch self {
        case .editor(let draft): return "draft-\(draft.id)"
        case .report(let report): return "report-\(report.id)"
        case .photos(let draft): return "photos-\(draft?.id.uuidString ?? "new")"
        }
    }
}
