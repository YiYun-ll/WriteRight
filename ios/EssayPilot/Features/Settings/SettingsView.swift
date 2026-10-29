import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("appearance") private var appearance = "system"
    @State private var exportFile: ExportFile?

    var body: some View {
        List {
            Section {
                HStack(spacing: 18) {
                    Image("BrandMark").resizable().scaledToFit().frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        BrandWordmark(size: 26, relativeTo: .title2)
                        Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")")
                            .font(.footnote).foregroundStyle(WriteRightTheme.secondary)
                    }
                }.padding(.vertical, 12)
            }
            Section {
                Picker("外观", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                Button {
                    do { exportFile = ExportFile(url: try model.exportURL()) }
                    catch { model.errorMessage = "未能导出练习，请重试。" }
                } label: { Label("导出练习", systemImage: "square.and.arrow.up") }
                NavigationLink { PrivacyView() } label: { Label("隐私", systemImage: "hand.raised") }
            }
        }.listStyle(.insetGrouped).scrollContentBackground(.hidden)
            .background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink).navigationTitle("我的")
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
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
            Section("扫描") { Text("OCR 转录需要你核对。识别的不确定文字不会被当作你的写作错误。") }
        }.navigationTitle("隐私").navigationBarTitleDisplayMode(.inline)
    }
}
