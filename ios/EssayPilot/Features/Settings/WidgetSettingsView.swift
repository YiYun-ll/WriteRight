import SwiftUI
import PhotosUI

struct WidgetSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var photo: PhotosPickerItem?
    @State private var saving = false
    @State private var message: String?
    var body: some View {
        List {
            Section {
                Toggle("在小组件展示记录", isOn: Binding(get: { model.widgetRecordsEnabled }, set: { model.setWidgetRecordsEnabled($0) }))
                    .accessibilityIdentifier("widget-records-toggle")
            } footer: { Text("开启后，桌面小组件显示未完成的待办或灵感链接。内容为倒计时或待办时显示待办，选灵感链接时显示链接。关闭或退出后清除。系统可能稍后刷新。") }
            Section {
                PhotosPicker(selection: $photo, matching: .images) { Label("从相册选择背景", systemImage: "photo") }.disabled(saving)
                    .accessibilityIdentifier("widget-background-choose")
                Button("移除照片背景", role: .destructive) {
                    do { try model.removeWidgetBackground(); message = "已移除照片背景。" }
                    catch { message = "背景未能移除，请重试。" }
                }
                if saving { ProgressView("正在保存…") }
                if let message { Text(message).font(.subheadline).foregroundStyle(WriteRightTheme.secondary) }
            } header: { Text("照片背景") } footer: { Text("照片只保存在这台手机，所有小组件共用。保存后会换掉午夜等纯色；移除后恢复小组件里选择的纯色。") }
            Section("添加与编辑") {
                Text("长按主屏幕空白处，添加 WriteRight 小组件。长按已添加的小组件，选择「编辑小组件」，即可分别设置内容和背景。")
                Text("内容可选：初试倒计时、待办事项、灵感链接。纯色背景可选：暖纸、鼠尾草、午夜。保存照片后，小组件改用照片。")
                Text("点击待办或灵感小组件，可进入 App 的记录页。陪写时会自动显示锁屏实时活动；可在系统设置中管理实时活动权限。")
            }
        }.scrollContentBackground(.hidden).background(WriteRightTheme.background).navigationTitle("桌面小组件")
            .onChange(of: photo) { _, item in
                guard let item else { return }; saving = true
                Task {
                    defer { saving = false; photo = nil }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                        try await model.saveWidgetBackground(data); message = "背景已保存，桌面小组件会改用这张照片。"
                    } catch WidgetStorageError.sharedAccessUnavailable {
                        message = "当前安装的签名未允许共享照片。请用原账户重签并保留小组件扩展与共享权限。"
                    } catch { message = "背景未能保存，请重新选择照片。" }
                }
            }
    }
}
