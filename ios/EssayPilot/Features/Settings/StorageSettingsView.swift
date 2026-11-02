import SwiftUI

struct StorageSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("reportPhotoCacheLimitMB") private var limitMB = 200
    @State private var usage = ReportPhotoCache.Usage(bytes: 0, files: 0)
    @State private var confirmingClear = false

    var body: some View {
        List {
            Section {
                LabeledContent("缓存原图", value: "\(usage.files) 张")
                LabeledContent("占用空间", value: usage.bytes.formatted(.byteCount(style: .file)))
                Picker("缓存上限", selection: $limitMB) {
                    Text("100 MB").tag(100)
                    Text("200 MB").tag(200)
                    Text("500 MB").tag(500)
                    Text("1 GB").tag(1000)
                }
            } footer: {
                Text("超过上限时，最久未读的缓存会先清理。本机拍摄的原稿不受影响。")
            }
            Section {
                Button("清理缓存", role: .destructive) { confirmingClear = true }
                    .disabled(usage.files == 0).accessibilityIdentifier("clear-report-cache")
            } footer: {
                Text("清理后，报告中的原图可在联网时重新下载。")
            }
        }
        .scrollContentBackground(.hidden).background(WriteRightTheme.background)
        .foregroundStyle(WriteRightTheme.ink).navigationTitle("原图缓存")
        .task { usage = model.reportCacheUsage() }
        .onChange(of: limitMB) { _, _ in
            _ = try? model.trimReportPhotoCache(); usage = model.reportCacheUsage()
        }
        .confirmationDialog("清理已缓存的原图？", isPresented: $confirmingClear) {
            Button("清理", role: .destructive) {
                _ = try? model.clearReportPhotoCache(); usage = model.reportCacheUsage()
            }
        }
    }
}
