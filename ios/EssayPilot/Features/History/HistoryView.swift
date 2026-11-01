import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""
    @State private var part = "all"
    @StateObject private var removal = PendingRemoval()
    let onOpen: (DraftDocument) -> Void
    let onCreate: () -> Void

    private var visible: [DraftDocument] { model.drafts.filter { !$0.isEmpty && !removal.hides($0.id) } }
    private var filtered: [DraftDocument] {
        visible.filter { draft in
            (part == "all" || draft.task.part.rawValue == part) &&
            (search.isEmpty || draft.task.displayTitle.localizedCaseInsensitiveContains(search) || draft.body.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        Group {
            if visible.isEmpty {
                ContentUnavailableView {
                    Label("还没有练习", systemImage: "text.book.closed")
                } actions: { Button("写一篇", action: onCreate).buttonStyle(.borderedProminent) }
            } else {
                VStack(spacing: 12) {
                    Picker("题型", selection: $part) {
                        Text("全部").tag("all")
                        ForEach(WritingPart.allCases) { Text($0.title).tag($0.rawValue) }
                    }.pickerStyle(.segmented).padding(.horizontal, 24)
                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else {
                        List {
                            ForEach(filtered) { draft in
                                Button { onOpen(draft) } label: { DraftRow(draft: draft) }
                                    .buttonStyle(.plain).listRowBackground(WriteRightTheme.surface)
                                    .swipeActions {
                                        Button("删除", role: .destructive) {
                                            removal.remove(id: draft.id, message: "已删除「\(draft.task.displayTitle)」") { model.delete(draft) }
                                        }
                                    }
                            }
                        }.listStyle(.insetGrouped).scrollContentBackground(.hidden)
                    }
                }.searchable(text: $search, prompt: "搜索题目或正文")
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(WriteRightTheme.background)
            .foregroundStyle(WriteRightTheme.ink).navigationTitle("历史")
            .undoableRemoval(removal, account: model.account?.userID)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("成绩") { PracticeStatsView() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("对比") { TaskCompareView() }
                }
            }
    }
}
