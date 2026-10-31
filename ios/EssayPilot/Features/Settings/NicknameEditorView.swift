import SwiftUI

struct NicknameEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var changed = false
    @FocusState private var focused: Bool
    var body: some View {
        Form {
            Section {
                TextField("想让我们怎样称呼你", text: Binding(get: { value }, set: { value = String($0.prefix(20)); changed = true }))
                    .textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused).disabled(model.isNicknameSaving)
                    .accessibilityIdentifier("nickname-field")
                HStack { Text("昵称"); Spacer(); Text("\(value.count) / 20").monospacedDigit() }.font(.caption).foregroundStyle(WriteRightTheme.secondary)
            } footer: { Text("给自己的书桌留一个名字。留空会恢复默认称呼；保存后随账号同步。") }
            if model.isNicknameLoading { ProgressView("正在读取昵称") }
            if let error = model.nicknameError {
                Section {
                    Text(error).font(.footnote).foregroundStyle(.red).accessibilityIdentifier("nickname-error")
                    if !changed { Button("重新读取") { Task { await model.refreshNickname() } } }
                }
            }
        }.scrollContentBackground(.hidden).background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
            .navigationTitle("修改昵称").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(model.isNicknameSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { if await model.saveNickname(value) { dismiss() } } } label: {
                        if model.isNicknameSaving { ProgressView() } else { Text("保存") }
                    }.disabled(model.isNicknameLoading || model.isNicknameSaving || model.account == nil || value.trimmingCharacters(in: .whitespacesAndNewlines) == (model.nickname ?? "")).accessibilityIdentifier("nickname-save")
                }
            }
            .onAppear { value = model.nickname ?? ""; focused = true }
            .onChange(of: model.nickname) { _, name in if !changed { value = name ?? "" } }
            .onChange(of: model.account?.userID) { _, _ in dismiss() }
            .interactiveDismissDisabled(model.isNicknameSaving)
    }
}
