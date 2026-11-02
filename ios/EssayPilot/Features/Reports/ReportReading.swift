import SwiftUI

struct ReportReadingControls: View {
    @Binding var requiredOnly: Bool
    @Binding var category: String
    @Binding var detailed: Bool
    let categories: [String]

    var body: some View {
        HStack(spacing: 12) {
            Menu {
                Toggle("只看必改", isOn: $requiredOnly)
                if !categories.isEmpty {
                    Picker("错误类型", selection: $category) {
                        Text("全部类型").tag("all")
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                }
            } label: {
                Label(requiredOnly || category != "all" ? "已筛选" : "筛选", systemImage: "line.3.horizontal.decrease")
                    .frame(minHeight: 44)
            }.accessibilityIdentifier("report-filter")
            Spacer()
            Picker("讲解详略", selection: $detailed) {
                Text("简洁").tag(false)
                Text("详细").tag(true)
            }.pickerStyle(.menu).frame(minHeight: 44).accessibilityIdentifier("report-detail")
        }.font(.subheadline)
    }
}

struct OriginalRevisionPair: View {
    let original: String
    let revised: String
    var revisedLabel = "建议修改"

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) {
                column("原句", original, accent: false)
                column(revisedLabel, revised, accent: true)
            }
            VStack(alignment: .leading, spacing: 14) {
                column("原句", original, accent: false)
                column(revisedLabel, revised, accent: true)
            }
        }
    }

    private func column(_ title: String, _ text: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(accent ? WriteRightTheme.accent : WriteRightTheme.secondary)
            Text(text).font(.system(.body, design: .serif)).lineSpacing(6).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
