import SwiftUI
import PhotosUI

struct ProfileAvatar: View {
    let data: Data?
    let size: CGFloat
    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill").resizable().scaledToFit()
                    .foregroundStyle(WriteRightTheme.accent.opacity(0.8), WriteRightTheme.background)
            }
        }.frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true)
    }
}

struct ProfileAvatarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: PhotosPickerItem?
    @State private var loading = false
    @State private var confirmRemoval = false
    var body: some View {
        List {
            Section {
                HStack { Spacer(); ProfileAvatar(data: model.avatarData, size: 160); Spacer() }.padding(.vertical, 28)
                    .listRowBackground(Color.clear)
                PhotosPicker(selection: $selection, matching: .images) {
                    Label("从相册选择头像", systemImage: "photo")
                }.disabled(loading).accessibilityIdentifier("avatar-choose")
                if loading { ProgressView("正在保存…") }
                if model.avatarData != nil {
                    Button("恢复默认头像", role: .destructive) { confirmRemoval = true }
                }
            } footer: { Text("头像仅保存在这台设备，按账号分别保存。只读取你选中的照片，不上传至 AI。") }
        }.scrollContentBackground(.hidden).background(WriteRightTheme.background).navigationTitle("头像")
            .confirmationDialog("恢复默认头像？", isPresented: $confirmRemoval, titleVisibility: .visible) {
                Button("恢复默认头像", role: .destructive) { model.removeAvatar() }
            }
            .onChange(of: selection) { _, item in
                guard let item else { return }
                let owner = model.profileOwner
                loading = true
                Task {
                    defer { loading = false; selection = nil }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
                        await model.saveAvatar(data, owner: owner)
                    } catch { model.errorMessage = "照片无法读取，请重新选择。" }
                }
            }
    }
}
