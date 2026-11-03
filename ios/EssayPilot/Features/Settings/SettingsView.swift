import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage("appearance") private var appearance = "system"
    @State private var exportFile: ExportFile?
    @State private var editingNickname = false
    @State private var importingBackup = false
    @State private var importResult: String?
    var onOpen: (DraftDocument) -> Void = { _ in }
    var onPractice: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                accountHeader
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 3), spacing: 10) {
                    NavigationLink { HistoryView(onOpen: onOpen, onCreate: onPractice) } label: {
                        statistic(model.drafts.filter { !$0.isEmpty }.count, title: "练习", symbol: "book.closed")
                    }.accessibilityIdentifier("profile-practice")
                    NavigationLink { ReportShelfView() } label: {
                        statistic(model.gradingReports.count, title: "报告", symbol: "doc.text")
                    }.accessibilityIdentifier("profile-reports")
                    NavigationLink { FavoritesView() } label: {
                        statistic(model.favorites.filter { $0.deletedAt == nil }.count, title: "收藏", symbol: "bookmark")
                    }.accessibilityIdentifier("profile-favorites")
                }.buttonStyle(.plain)
                if model.guestDraftCount > 0 && model.account != nil {
                    Button { model.migrateGuestDrafts() } label: {
                        row("迁入本机草稿", symbol: "tray.and.arrow.down", detail: "\(model.guestDraftCount)篇本机练习还在等你收好")
                    }.buttonStyle(.plain).accessibilityIdentifier("migrate-guest-drafts")
                }
                section("学习记录") {
                    NavigationLink { PracticeStatsView() } label: { row("成绩曲线", symbol: "chart.xyaxis.line") }
                    Divider()
                    NavigationLink { TaskCompareView() } label: { row("同题对比", symbol: "square.split.2x1") }
                }
                section("数据管理") {
                    Button { Task { await model.refreshNickname(); await model.syncNow() } } label: {
                        row("立即同步", symbol: "arrow.triangle.2.circlepath", detail: model.syncStatusDetail, chevron: false)
                    }.disabled(model.syncState == "正在同步").accessibilityIdentifier("sync-now")
                    Divider()
                    Button {
                        do { exportFile = ExportFile(url: try model.exportURL()) }
                        catch { model.errorMessage = "未能导出练习，请重试。" }
                    } label: { row("导出练习", symbol: "square.and.arrow.up") }.accessibilityIdentifier("profile-export")
                    Divider()
                    Button { importingBackup = true } label: {
                        row("导入备份", symbol: "tray.and.arrow.down", detail: "合并练习与原图，不覆盖当前内容")
                    }.accessibilityIdentifier("profile-import")
                    Divider()
                    NavigationLink { StorageSettingsView() } label: { row("原图缓存", symbol: "internaldrive") }
                    Divider()
                    NavigationLink { PrivacyView() } label: { row("隐私与原稿", symbol: "hand.raised") }
                }
                section("通用") {
                    HStack(spacing: 14) {
                        Image(systemName: "circle.lefthalf.filled").font(.system(size: 20)).frame(width: 25).foregroundStyle(WriteRightTheme.accent)
                        Picker("外观", selection: $appearance) {
                            Text("跟随系统").tag("system"); Text("浅色").tag("light"); Text("深色").tag("dark")
                        }.pickerStyle(.menu)
                    }.frame(minHeight: 56)
                    Divider()
                    NavigationLink { WidgetSettingsView() } label: { row("桌面小组件", symbol: "square.grid.2x2") }.accessibilityIdentifier("profile-widgets")
                    Divider()
                    NavigationLink { WritingHelpView() } label: { row("使用帮助", symbol: "questionmark.circle") }.accessibilityIdentifier("profile-help")
                    Divider()
                    NavigationLink { AboutWriteRightView() } label: { row("关于 WriteRight", symbol: "leaf") }.accessibilityIdentifier("profile-about")
                }

            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink).navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(WriteRightTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable { await model.refreshNickname(); if model.account != nil { await model.syncNow() } }
            .sheet(isPresented: $editingNickname) { NavigationStack { NicknameEditorView() } }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    let summary = try model.importBackup(data: Data(contentsOf: url))
                    importResult = "已收好 \(summary.added) 项内容和 \(summary.images) 张原图。已有内容没有被覆盖。"
                } catch { model.errorMessage = error.localizedDescription }
            }
            .alert("备份已导入", isPresented: Binding(get: { importResult != nil }, set: { if !$0 { importResult = nil } })) {
                Button("好") { importResult = nil }
            } message: { Text(importResult ?? "") }
    }
    private var accountHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            NavigationLink { ProfileAvatarView() } label: {
                ProfileAvatar(data: model.avatarData, size: 68)
            }.buttonStyle(.plain).accessibilityLabel("更换头像").accessibilityIdentifier("profile-avatar")
            VStack(alignment: .leading, spacing: 4) {
                if let account = model.account {
                    Button { editingNickname = true } label: {
                        HStack(spacing: 8) {
                            Text(model.nickname ?? "WriteRight 用户").font(.title3.weight(.semibold)).lineLimit(2).accessibilityIdentifier("profile-nickname")
                            Image(systemName: "pencil").font(.caption)
                        }.frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityLabel("修改昵称，\(model.nickname ?? "尚未设置")").accessibilityIdentifier("profile-edit-nickname")
                    NavigationLink { AccountView() } label: {
                        HStack { Text(maskedEmail(account.email)); Image(systemName: "chevron.right").font(.caption) }
                            .font(.subheadline).foregroundStyle(WriteRightTheme.secondary).frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityIdentifier("account-link")
                } else {
                    NavigationLink { LoginView() } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("登录 / 注册").font(.title3.weight(.semibold)); Image(systemName: "chevron.right").font(.caption) }
                            Text("登录后同步学习记录").font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                        }.frame(minHeight: 64)
                    }.buttonStyle(.plain).accessibilityIdentifier("login-link")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(18).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
    private func maskedEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard let name = parts.first, parts.count == 2 else { return "账号与登录" }
        return "\(name.prefix(1))•••@\(parts[1])"
    }
    private func statistic(_ count: Int, title: String, symbol: String) -> some View {
        VStack(spacing: 10) {
            Text(count.formatted()).font(.system(.title, design: .serif))
            Label(title, systemImage: symbol).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
        }.frame(maxWidth: .infinity, minHeight: 106).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18))
    }
    private func row(_ title: String, symbol: String, detail: String? = nil, chevron: Bool = true) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 20)).frame(width: 25).foregroundStyle(WriteRightTheme.accent)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.body)
                if let detail { Text(detail).font(.caption).foregroundStyle(WriteRightTheme.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if chevron { Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(WriteRightTheme.secondary) }
        }.frame(minHeight: detail == nil ? 56 : 68).contentShape(Rectangle())
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(WriteRightTheme.secondary)
            VStack(spacing: 0, content: content).padding(.horizontal, 18).padding(.vertical, 4)
                .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18)).buttonStyle(.plain)
        }
    }
}

private struct ReportShelfView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var removal = PendingRemoval()
    @State private var selected: GradingReportDocument?
    @State private var exportFile: ExportFile?
    @State private var search = ""
    @State private var part = "all"
    @State private var selecting = false
    @State private var selectedIDs: Set<UUID> = []

    private var visible: [GradingReportDocument] {
        model.gradingReports.filter { !removal.hides($0.id) }.sorted { $0.createdAt > $1.createdAt }
    }
    private var filtered: [GradingReportDocument] {
        visible.filter { report in
            guard part == "all" || report.part.rawValue == part else { return false }
            let title = model.submissions.first(where: { $0.id == report.submissionID })?.task.displayTitle ?? ""
            return search.isEmpty || title.localizedCaseInsensitiveContains(search)
                || report.report.overallComment.localizedCaseInsensitiveContains(search)
                || report.part.title.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        Group {
            if visible.isEmpty {
                ContentUnavailableView("还没有回信", systemImage: "doc.text", description: Text("完成一次批改后，报告会收在这里。"))
            } else {
                VStack(spacing: 0) {
                    Picker("题型", selection: $part) {
                        Text("全部").tag("all")
                        ForEach(WritingPart.allCases) { Text($0.title).tag($0.rawValue) }
                    }.pickerStyle(.segmented).padding(.horizontal, 24).padding(.vertical, 10)
                    if filtered.isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else {
                        List(filtered) { report in row(report) }
                            .listStyle(.insetGrouped).scrollContentBackground(.hidden)
                    }
                }
            }
        }
        .background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
        .navigationTitle("我的报告")
        .searchable(text: $search, prompt: "搜索题目或点评")
        .undoableRemoval(removal, account: model.account?.userID)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(selecting ? "完成" : "选择") {
                    selecting.toggle(); if !selecting { selectedIDs = [] }
                }.accessibilityIdentifier("report-select")
            }
            if selecting {
                ToolbarItem(placement: .topBarLeading) {
                    Button(selectedIDs.isEmpty ? "全选" : "删除 \(selectedIDs.count) 份报告", role: .destructive) {
                        if selectedIDs.isEmpty { selectedIDs = Set(filtered.map(\.id)) }
                        else { deleteSelected() }
                    }.accessibilityIdentifier("report-batch-delete")
                }
            }
        }
        .fullScreenCover(item: $selected) { GradingReportView(document: $0) }
        .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
    }

    private func row(_ report: GradingReportDocument) -> some View {
        HStack(spacing: 14) {
            if selecting {
                Image(systemName: selectedIDs.contains(report.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(WriteRightTheme.accent).frame(width: 28)
            }
            Button {
                if selecting {
                    if selectedIDs.contains(report.id) { selectedIDs.remove(report.id) } else { selectedIDs.insert(report.id) }
                } else { selected = report }
            } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.submissions.first(where: { $0.id == report.submissionID })?.task.displayTitle ?? report.part.title)
                            .font(.headline).multilineTextAlignment(.leading)
                        Text("\(report.part.title) · \(report.createdAt.formatted(.dateTime.month().day().hour().minute()))")
                            .font(.caption).foregroundStyle(WriteRightTheme.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(report.report.score.value.map { "\($0.formatted()) / \(report.report.score.max)" } ?? "语言反馈")
                        .font(.system(.title3, design: .serif)).fixedSize()
                }.padding(.vertical, 10).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("report-row")
            if !selecting {
                Menu {
                    Button("导出报告") {
                        do { exportFile = ExportFile(url: try model.exportReportURL(report)) }
                        catch { model.errorMessage = "未能导出报告，请重试。" }
                    }.accessibilityIdentifier("report-export")
                    Button("删除", role: .destructive) {
                        removal.remove(id: report.id, message: "已删除\(report.part.title)报告") { model.delete(report) }
                    }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                    .accessibilityLabel("报告操作")
            }
        }
        .listRowBackground(WriteRightTheme.surface)
        .swipeActions {
            if !selecting {
                Button("删除", role: .destructive) {
                    removal.remove(id: report.id, message: "已删除\(report.part.title)报告") { model.delete(report) }
                }
            }
        }
    }

    private func deleteSelected() {
        let documents = model.gradingReports.filter { selectedIDs.contains($0.id) }
        let count = documents.count
        removal.remove(ids: selectedIDs, message: "已删除 \(count) 份报告") {
            documents.forEach { model.delete($0) }
        }
        selecting = false; selectedIDs = []
    }
}

private struct WritingHelpView: View {
    var body: some View {
        List {
            Section("从一页开始") {
                DisclosureGroup("怎样用照片批改？") { Text("在练习页选择照片批改，把完整题目与作文分别放好，按页排序后开始。题图和作文一起交给 AI，不需要先转文字。原稿会保留在报告中，可以放大回看。") }
                DisclosureGroup("没有题图，可以继续吗？") { Text("可以。没有完整题目，或关键内容看不清时，只提供能够确认的语言建议，不给完整任务总分。") }
                DisclosureGroup("等待时能离开吗？") { Text("上传成功后，云端会继续批改。可以离开页面，之后从练习页的任务或报告回来看。上传未完成时请先等照片送达。") }
            }
            Section("读懂一封回信") {
                DisclosureGroup("分数应该怎样看？") { Text("小作文满分10分，大作文满分15分，分别使用各自标准。AI 是模拟估分，不替代正式阅卷；参考区间也不是统计保证。一次分数不能概括你的全部能力。") }
                DisclosureGroup("必改和可选表达有什么不同？") { Text("必改用于可确认的语言或表达问题。可选表达只是另一种说法，不代表原句有错。读图疑点应先看原图，不算作你的写作错误。") }
                DisclosureGroup("怎样收藏和同题再写？") { Text("在报告的复盘页点击收藏，成功后会变为已收藏。可以在我的收藏夹或首页书页一角重读。练习页的再写一稿会保留题目；照片稿复用同一张题图后，已有报告的两次练习可以同题对比。") }
            }
            Section("照顾好原稿") {
                DisclosureGroup("断网后照片和草稿还在吗？") { Text("已保存的草稿在本机。在线批改需要网络；失败时保留原稿和任务，可稍后重试。换手机后仍需要登录同一账号并同步；请先确认重要内容已经同步或导出。") }
                DisclosureGroup("首页的小猫会怎样长大？") { Text("每天来书桌坐坐、摸摸它、喂小鱼干、一起专注写一会儿，以及收到真实的批改报告，都会让它慢慢长大，一共六个阶段。几天没来不会倒退，也没有连续打卡。登录后，它的名字、来访日期和陪写分钟随账号同步，换手机也会接着长大；两台设备的记录会合在一起，不会互相覆盖。未登录时只留在本机。这些记录不发送给 AI，删除账号会一并清理。") }
                DisclosureGroup("以前的首页便笺去哪了？") { Text("首页便笺已换成陪伴小窝。如果你写过便笺，打开「记录」会看到它，可以收进记录或删除；在你选择之前，它一直只留在本机。") }
            }
        }.scrollContentBackground(.hidden).background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
            .navigationTitle("使用帮助").navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutWriteRightView: View {
    @State private var unfolded = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image("BrandMark").resizable().scaledToFit().frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                BrandWordmark(size: 32, relativeTo: .largeTitle)
                Text("把想法写清楚，也给自己一点耐心。").font(.system(.title2, design: .serif)).lineSpacing(6)
                Text("WriteRight 陪你练习考研英语二写作。原稿、建议和每一次重新落笔，都是这本写作本的一部分。")
                    .font(.body).lineSpacing(6)
                Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0") · \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")").font(.footnote).foregroundStyle(WriteRightTheme.secondary)
                Button { unfolded.toggle() } label: { Label("留给翻到这里的你", systemImage: "leaf").frame(minHeight: 44) }.buttonStyle(.plain)
                if unfolded { GentleNote(text: "谢谢你愿意再写一次。愿这本小小的写作本，能在某个不容易的晚上，让你少一点孤单。") }
            }.padding(28).frame(maxWidth: 620, alignment: .leading).frame(maxWidth: .infinity)
        }.background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink).navigationTitle("关于").navigationBarTitleDisplayMode(.inline)
    }
}

private struct ExportFile: Identifiable { let id = UUID(); let url: URL }
private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct PrivacyView: View {
    var body: some View {
        List {
            Section("练习与原稿") { Text("草稿保存在本机。导出的文件包含题目和作文，请妥善保管。") }
            Section("AI 批改") { Text("使用在线批改时，题目和作文会发送到服务端及 DeepSeek。AI 分数属于模拟估计，不能代替正式阅卷。") }
            Section("照片与原稿") {
                Text("照片直接用于 AI 批改，不先转成核对稿。题目与作文原图保留在你的私有空间供报告回看；读图可能出错，请以原稿为准。关键内容不清时不估总分。")

            }
        }
        .navigationTitle("隐私")
        .navigationBarTitleDisplayMode(.inline)
    }
}
