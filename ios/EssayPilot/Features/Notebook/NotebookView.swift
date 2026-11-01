import SwiftUI

struct NotebookView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editing: NotebookEntry?
    @State private var filter = "pending"
    @State private var search = ""
    @State private var removed: NotebookEntry?
    @State private var response: String?
    @State private var openFailed = false
    @State private var source: String?
    @State private var legacyNote: String?
    @State private var confirmLegacyDiscard = false
    private var owner: String { app.account?.userID.uuidString ?? "guest" }
    private var linkSources: [NotebookPresentation.LinkSource] { NotebookPresentation.linkSources(app.notebook) }
    private var activeSource: String? { linkSources.contains { $0.title == source } ? source : nil }
    private var sections: [NotebookPresentation.Section] { NotebookPresentation.sections(app.notebook, filter: filter, search: search, source: filter == "links" ? activeSource : nil) }
    private var completedCount: Int { app.notebook.filter(\.completed).count }
    private var animation: Animation? { reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.88) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                header
                Button { editing = NotebookEntry(kind: filter == "links" ? .link : .task, title: "") } label: {
                    Label("记下一件事", systemImage: "plus").font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(WriteRightTheme.onAccent)
                    .background(WriteRightTheme.accent, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("notebook-add")
                HStack(alignment: .firstTextBaseline) {
                    Picker("查看记录", selection: $filter) {
                        Text("手边").tag("pending"); Text("灵感链接").tag("links")
                        Text("已完成").tag("done"); Text("全部").tag("all")
                    }.pickerStyle(.menu).tint(WriteRightTheme.accent).accessibilityIdentifier("notebook-filter")
                    Spacer(minLength: 0)
                    if !search.isEmpty { Text("搜索结果").font(.footnote).foregroundStyle(WriteRightTheme.secondary) }
                }
                if filter == "links", linkSources.count > 1 { sourceShelf }
                if let legacyNote { legacyNoteCard(legacyNote) }
                if let response {
                    Text(response).font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary)
                        .lineSpacing(4).accessibilityIdentifier("notebook-response").transition(.opacity)
                }
                if sections.isEmpty { emptyPage }
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Text(section.title).font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary)
                            Rectangle().fill(WriteRightTheme.soft).frame(height: 1).accessibilityHidden(true)
                        }.accessibilityAddTraits(.isHeader)
                        ForEach(section.entries) { entry in
                            row(entry).transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                if filter == "pending", completedCount > 0, search.isEmpty {
                    Button { withAnimation(animation) { filter = "done"; response = nil } } label: {
                        HStack { Image(systemName: "checkmark.circle"); Text("看看已收好的 \(completedCount) 条"); Spacer(); Image(systemName: "chevron.right") }
                            .font(.subheadline).frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(WriteRightTheme.secondary).accessibilityIdentifier("notebook-show-completed")
                }
                Text(app.account == nil ? "未登录的记录留在本机；登录后使用账号自己的书页。" : "下拉可同步记录，离线编辑先留在本机。")
                    .font(.footnote).foregroundStyle(WriteRightTheme.secondary).lineSpacing(4)
            }.padding(24).padding(.bottom, 24)
        }
        .background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
        .navigationTitle("记录").navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WriteRightTheme.background, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $search, prompt: "找一件小事，或一段灵感")
        .refreshable { await app.syncNow() }
        .sheet(item: $editing) { entry in
            NotebookEditor(entry: entry) { saved in
                guard app.saveNotebook(saved) else { return false }
                // A successful save must not disappear behind an old search/completed filter.
                search = ""; source = nil
                if filter == "done" && !saved.completed || filter == "links" && saved.safeURL == nil { filter = "pending" }
                if saved.completed && filter == "pending" { filter = "done" }
                return true
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let removed {
                HStack {
                    Text("已收起这条记录").font(.subheadline)
                    Spacer()
                    Button("撤销") { if app.restoreNotebook(removed) { self.removed = nil } }
                        .frame(minHeight: 44).accessibilityIdentifier("notebook-undo")
                }.padding(.horizontal, 24).background(WriteRightTheme.surface)
            }
        }
        .alert("链接暂时未能打开", isPresented: $openFailed) { Button("知道了", role: .cancel) {} } message: { Text("记录仍在。可以进入编辑，检查或复制链接后再试。") }
        .confirmationDialog("删除以前的首页便笺？", isPresented: $confirmLegacyDiscard, titleVisibility: .visible) {
            Button("删除这段便笺", role: .destructive) { LegacyDeskNote.erase(owner: owner); legacyNote = nil }
        } message: { Text("删除后无法找回。") }
        .onAppear { legacyNote = LegacyDeskNote.load(owner: owner) }
        .onChange(of: filter) { _, _ in source = nil }
        .onChange(of: app.account?.userID) { _, _ in
            editing = nil; removed = nil; response = nil; search = ""; filter = "pending"; source = nil
            legacyNote = LegacyDeskNote.load(owner: owner)
        }
    }
    private var sourceShelf: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                sourceChip("全部来源", count: linkSources.reduce(0) { $0 + $1.count }, selected: activeSource == nil, id: "notebook-source-all") { source = nil }
                ForEach(linkSources) { item in
                    sourceChip(item.title, count: item.count, selected: activeSource == item.title, id: "notebook-source-" + item.title) { source = item.title }
                }
            }
        }.accessibilityElement(children: .contain).accessibilityLabel("按链接来源整理")
    }
    private func sourceChip(_ title: String, count: Int, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button { withAnimation(animation) { action() } } label: {
            HStack(spacing: 6) { Text(title); Text("\(count)").monospacedDigit().foregroundStyle(selected ? WriteRightTheme.accent : WriteRightTheme.secondary) }
                .font(.subheadline).padding(.horizontal, 14).frame(minHeight: 40)
                .foregroundStyle(selected ? WriteRightTheme.accent : WriteRightTheme.ink)
                .background(selected ? WriteRightTheme.surface : Color.clear, in: Capsule())
                .overlay { Capsule().strokeBorder(selected ? WriteRightTheme.accent.opacity(0.35) : WriteRightTheme.secondary.opacity(0.2)) }
                .contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityLabel("\(title)，\(count) 条").accessibilityAddTraits(selected ? [.isSelected] : [])
            .accessibilityIdentifier(id)
    }
    private func legacyNoteCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("以前留在首页的便笺").font(.system(.headline, design: .serif))
            Text(note).font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            Text(app.account == nil ? "首页换成了陪伴小窝，这段话还留在本机。收进记录后，可以和其他小事放在一起。" : "首页换成了陪伴小窝，这段话目前只在本机。收进记录后，会像其他记录一样随账号同步。")
                .font(.footnote).foregroundStyle(WriteRightTheme.secondary).lineSpacing(3)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { legacyActions(note) }
                VStack(alignment: .leading, spacing: 4) { legacyActions(note) }
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(WriteRightTheme.soft.opacity(0.65), in: RoundedRectangle(cornerRadius: 18))
            .accessibilityIdentifier("notebook-legacy-note")
    }
    @ViewBuilder private func legacyActions(_ note: String) -> some View {
        Button {
            let title = note.split(whereSeparator: \.isNewline).first.map { String($0.prefix(120)) } ?? "首页便笺"
            if app.saveNotebook(NotebookEntry(kind: .note, title: title, note: note)) {
                LegacyDeskNote.erase(owner: owner); legacyNote = nil
                withAnimation(animation) { response = "便笺已经收进记录，放在「留下的片刻」里。" }
            }
        } label: { Text("收进记录").font(.subheadline.weight(.medium)).frame(minHeight: 44) }
            .buttonStyle(.plain).foregroundStyle(WriteRightTheme.accent).accessibilityIdentifier("notebook-legacy-keep")
        Button("不需要了") { confirmLegacyDiscard = true }.font(.subheadline).frame(minHeight: 44)
            .foregroundStyle(WriteRightTheme.secondary).accessibilityIdentifier("notebook-legacy-discard")
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                Text("给生活，\n留一点空白。")
                    .font(.system(.title, design: .serif)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "text.book.closed").font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(WriteRightTheme.accent).padding(.top, 8).accessibilityHidden(true)
            }
            Text("想做的小事，舍不得划走的片刻，先放在这里。")
                .font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary).lineSpacing(5)
        }.padding(.vertical, 8)
    }
    private var emptyPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(!search.isEmpty ? "这一页里，还没找到它。" : filter == "done" ? "没有划下勾，也没有关系。" : filter == "links" ? "把想再看的片刻，留在这里。" : "这一页，等你慢慢填。")
                .font(.system(.title3, design: .serif))
            Text(!search.isEmpty ? "换个关键词，或清空搜索再看看。" : filter == "links" ? "点「记下一件事」，选择灵感链接，把哔哩哔哩、公众号、小红书或抖音的整段分享文字粘贴进来就好，会按来源自动归好。" : "可以只记一件小事。完成不是比赛，晚一点也来得及。")
                .font(.subheadline).foregroundStyle(WriteRightTheme.secondary).lineSpacing(5)
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
    private func row(_ entry: NotebookEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                if entry.kind == .task {
                    Button { toggle(entry) } label: {
                        Image(systemName: entry.completed ? "checkmark.circle.fill" : "circle").font(.system(size: 23)).frame(width: 44, height: 44)
                    }.buttonStyle(.plain).foregroundStyle(WriteRightTheme.accent)
                        .accessibilityLabel("\(NotebookPresentation.completionLabel(entry))：\(entry.title)").accessibilityIdentifier("notebook-complete")
                }
                Button { editing = entry } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(entry.title).font(.system(.headline, design: .serif))
                            .strikethrough(entry.completed && entry.kind == .task).fixedSize(horizontal: false, vertical: true)
                        if !NotebookPresentation.preview(entry).isEmpty {
                            Text(NotebookPresentation.preview(entry)).font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary).lineLimit(3).lineSpacing(4)
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) { metadata(entry) }
                            VStack(alignment: .leading, spacing: 5) { metadata(entry) }
                        }.font(.caption).foregroundStyle(WriteRightTheme.secondary)
                    }.padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityHint("轻点编辑这条记录").accessibilityIdentifier("notebook-edit")
                Menu {
                    Button("编辑") { editing = entry }
                    Button(NotebookPresentation.completionLabel(entry)) { toggle(entry) }
                    Button(entry.pinned ? "取消置顶" : "置顶") { var saved = entry; saved.pinned.toggle(); _ = withAnimation(animation) { app.saveNotebook(saved) } }
                    Button("收起这条记录", role: .destructive) {
                        var saved = entry; saved.deletedAt = .now
                        if withAnimation(animation, { app.saveNotebook(saved) }) { removed = entry }
                    }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    .accessibilityLabel("记录操作：\(entry.title)").accessibilityIdentifier("notebook-menu")
            }
            if let url = entry.safeURL {
                Divider().overlay(WriteRightTheme.soft)
                Button { openURL(url) { accepted in if !accepted { openFailed = true } } } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "arrow.up.right.square").font(.title3.weight(.light))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("打开\(NotebookLink.source(url))链接").font(.subheadline)
                            Text(url.host ?? "").font(.caption).foregroundStyle(WriteRightTheme.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer(minLength: 0); Image(systemName: "arrow.up.right").font(.caption)
                    }.frame(minHeight: 52).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(WriteRightTheme.accent).accessibilityIdentifier("notebook-open-link")
            }
        }.padding(16).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
    @ViewBuilder private func metadata(_ entry: NotebookEntry) -> some View {
        if entry.pinned { Label("置顶", systemImage: "pin").fixedSize() }
        Text(entry.completed ? (entry.kind == .link ? "已看过" : entry.kind == .task ? "已完成" : "已收好") : entry.kind.title).fixedSize()
        if let date = entry.dueDate { Text(NotebookPresentation.dateLabel(date)).fixedSize(horizontal: false, vertical: true) }
    }
    private func toggle(_ entry: NotebookEntry) {
        var changed = entry; changed.completed.toggle()
        let saved = withAnimation(animation) { app.saveNotebook(changed) }
        if saved {
            withAnimation(animation) {
                response = changed.completed ? (entry.kind == .task ? "这一件，已经走过了。放进已完成，剩下的慢慢来。" : "已经收好。想再看时，随时可以找回来。") : "重新放回眼前，按自己的节奏来。"
                if !changed.completed && filter == "done" { filter = "pending" }
            }
        }
    }
}

private struct NotebookEditor: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: NotebookEditorModel
    let save: (NotebookEntry) -> Bool
    init(entry: NotebookEntry, save: @escaping (NotebookEntry) -> Bool) {
        _model = StateObject(wrappedValue: NotebookEditorModel(entry: entry)); self.save = save
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("这一条是", selection: $model.entry.kind) { ForEach(NotebookEntry.Kind.allCases) { Text($0.title).tag($0) } }
                        .pickerStyle(.menu).accessibilityIdentifier("notebook-kind")
                    TextField("标题，也可以稍后再起", text: $model.entry.title, axis: .vertical).accessibilityIdentifier("notebook-title")
                    TextField(model.entry.kind == .task ? "想做什么？把第一小步写下来。" : "想留住什么？一句话也很好。", text: $model.entry.note, axis: .vertical)
                        .lineLimit(3...8).accessibilityIdentifier("notebook-note")
                } footer: { Text("标题留空时，会用你写下的第一行或链接来源来命名。") }
                Section {
                    if model.entry.kind == .link || model.includeLink {
                        TextField("粘贴链接或整段分享文字", text: $model.linkInput, axis: .vertical)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("notebook-link")
                        if let url = model.detectedURL {
                            Label("\(NotebookLink.source(url)) · \(url.host ?? "")", systemImage: "link").font(.footnote).foregroundStyle(WriteRightTheme.secondary)
                        }
                        if model.entry.kind != .link { Button("移除链接", role: .destructive) { model.includeLink = false; model.linkInput = "" }.accessibilityIdentifier("notebook-link-remove") }
                    } else {
                        Button { model.includeLink = true } label: { Label("附上一个链接", systemImage: "link") }.accessibilityIdentifier("notebook-link-expand")
                    }
                } footer: {
                    if model.includeLink || model.entry.kind == .link { Text("只保存你提供的文字与链接，不抓取内容或发送给 AI。点击后由系统打开原网页或对应 App。") }
                }
                Section {
                    Toggle("留给某一天", isOn: $model.schedule)
                    if model.schedule { DatePicker("日期", selection: $model.date, displayedComponents: .date) }
                    Toggle("放在最前面", isOn: $model.entry.pinned)
                }
                if let error = model.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("notebook-editor-error") }
            }.scrollContentBackground(.hidden).background(WriteRightTheme.background)
                .navigationTitle("留一笔").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("收好") {
                        guard let entry = model.prepare() else { return }
                        if save(entry) { dismiss() } else { model.error = "暂时未能保存，输入仍在，请重试。" }
                    }.accessibilityIdentifier("notebook-save") }
                }
        }.onChange(of: model.entry.kind) { _, kind in if kind == .link { model.includeLink = true } }
    }
}
