import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage("appearance") private var appearance = "system"
    @State private var exportFile: ExportFile?
    @State private var editingNickname = false
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
                section("慢慢积累") {
                    NavigationLink { PracticeStatsView() } label: { row("成绩曲线", symbol: "chart.xyaxis.line", detail: "看见每一次练习的刻度") }
                    Divider()
                    NavigationLink { TaskCompareView() } label: { row("同题对比", symbol: "square.split.2x1", detail: "把两次表达放在一起看") }
                }
                section("数据与安心") {
                    Button { Task { await model.refreshNickname(); await model.syncNow() } } label: {
                        row("立即同步", symbol: "arrow.triangle.2.circlepath", detail: model.syncState, chevron: false)
                    }.disabled(model.syncState == "正在同步").accessibilityIdentifier("sync-now")
                    Divider()
                    Button {
                        do { exportFile = ExportFile(url: try model.exportURL()) }
                        catch { model.errorMessage = "未能导出练习，请重试。" }
                    } label: { row("导出练习", symbol: "square.and.arrow.up") }.accessibilityIdentifier("profile-export")
                    Divider()
                    NavigationLink { PrivacyView() } label: { row("隐私与原稿", symbol: "hand.raised") }
                }
                section("使用与偏好") {
                    HStack(spacing: 14) {
                        Image(systemName: "circle.lefthalf.filled").font(.system(size: 20)).frame(width: 25).foregroundStyle(WriteRightTheme.accent)
                        Picker("外观", selection: $appearance) {
                            Text("跟随系统").tag("system"); Text("浅色").tag("light"); Text("深色").tag("dark")
                        }.pickerStyle(.menu)
                    }.frame(minHeight: 56)
                    Divider()
                    NavigationLink { WritingHelpView() } label: { row("使用帮助", symbol: "questionmark.circle") }.accessibilityIdentifier("profile-help")
                    Divider()
                    NavigationLink { AboutWriteRightView() } label: { row("关于 WriteRight", symbol: "leaf") }.accessibilityIdentifier("profile-about")
                }
                Text("写过的每一页，都算数。")
                    .font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }.padding(24).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink).navigationTitle("我的")
            .toolbarBackground(WriteRightTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable { await model.refreshNickname(); if model.account != nil { await model.syncNow() } }
            .sheet(isPresented: $editingNickname) { NavigationStack { NicknameEditorView() } }
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
    }
    @ViewBuilder private var accountHeader: some View {
        if let account = model.account {
            HStack(spacing: 18) {
                Image("BrandMark").resizable().scaledToFit().frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 17)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Button { editingNickname = true } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(model.nickname ?? "你的写作书桌").font(.system(.title3, design: .serif)).lineLimit(2).accessibilityIdentifier("profile-nickname")
                            Image(systemName: "pencil").font(.system(size: 14)).foregroundStyle(WriteRightTheme.accent)
                        }.frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityLabel("修改昵称，\(model.nickname ?? "尚未设置")").accessibilityIdentifier("profile-edit-nickname")
                    NavigationLink { AccountView() } label: {
                        HStack { Text(maskedEmail(account.email)); Image(systemName: "chevron.right").font(.system(size: 12)) }.font(.subheadline).foregroundStyle(WriteRightTheme.secondary).frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityIdentifier("account-link")
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.vertical, 8)
        } else {
            NavigationLink { LoginView() } label: {
                header(title: "欢迎来坐坐", subtitle: "登录，收好你的练习与回信")
            }.buttonStyle(.plain).accessibilityIdentifier("login-link")
        }
    }
    private func header(title: String, subtitle: String) -> some View {
        HStack(spacing: 18) {
            Image("BrandMark").resizable().scaledToFit().frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 17)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 9) {
                Text(title).font(.system(.title3, design: .serif))
                Text(subtitle).font(.subheadline).foregroundStyle(WriteRightTheme.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(WriteRightTheme.secondary)
        }.padding(.vertical, 14)
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
            Text(title).font(.system(.headline, design: .serif)).foregroundStyle(WriteRightTheme.secondary)
            VStack(spacing: 0, content: content).padding(.horizontal, 18).padding(.vertical, 4)
                .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18)).buttonStyle(.plain)
        }
    }
}

private struct ReportShelfView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selected: GradingReportDocument?
    var body: some View {
        Group {
            if model.gradingReports.isEmpty { ContentUnavailableView("还没有回信", systemImage: "doc.text", description: Text("完成一次批改后，报告会收在这里。")) }
            else {
                List(model.gradingReports.sorted { $0.createdAt > $1.createdAt }) { report in
                    Button { selected = report } label: {
                        HStack(spacing: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(report.part.title).font(.headline)
                                Text(report.createdAt, format: .dateTime.month().day()).font(.caption).foregroundStyle(WriteRightTheme.secondary)
                            }; Spacer()
                            Text(report.report.score.value.map { "\($0.formatted()) / \(report.report.score.max)" } ?? "语言反馈").font(.system(.title3, design: .serif))
                        }.padding(.vertical, 10)
                    }.buttonStyle(.plain).listRowBackground(WriteRightTheme.surface)
                }.scrollContentBackground(.hidden)
            }
        }.background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink).navigationTitle("我的报告")
            .fullScreenCover(item: $selected) { GradingReportView(document: $0) }
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
                DisclosureGroup("首页便笺会同步吗？") { Text("口袋便笺只保存在这台设备的当前账号里，不会发送给 AI，也不参与云同步。退出登录会隐藏；删除账号会清理该账号在本机的便笺。") }
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
                Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0") · \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")").font(.footnote).foregroundStyle(WriteRightTheme.secondary)
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
