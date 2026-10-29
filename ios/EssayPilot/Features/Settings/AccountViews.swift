import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var resendAt = Date.distantPast
    @FocusState private var focusedField: Field?

    private enum Field { case email, code }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image("BrandMark").resizable().scaledToFit().frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 15)).accessibilityHidden(true)
                VStack(spacing: 16) {
                    TextField("邮箱", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .disabled(codeSent || model.isAuthBusy)
                        .accessibilityIdentifier("auth-email")
                    if codeSent {
                        TextField("验证码", text: $code)
                            .textContentType(.oneTimeCode).keyboardType(.numberPad)
                            .focused($focusedField, equals: .code)
                            .accessibilityIdentifier("auth-code")
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .textFieldStyle(.plain).padding(20).glassSurface()
                .animation(.smooth, value: codeSent)

                Button {
                    Task { if codeSent { await verify() } else { await sendCode() } }
                } label: {
                    Group {
                        if model.isAuthBusy { ProgressView().tint(.white) }
                        else { Text(codeSent ? "登录" : "发送验证码") }
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(MainActionStyle())
                .disabled(model.isAuthBusy || email.isEmpty || (codeSent && code.count != 6))
                .accessibilityIdentifier(codeSent ? "auth-verify" : "auth-send")

                if codeSent {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(resendAt.timeIntervalSince(context.date).rounded(.up)))
                        Button(remaining > 0 ? "重新发送（\(remaining) 秒）" : "重新发送验证码") {
                            Task { await sendCode() }
                        }
                        .disabled(remaining > 0 || model.isAuthBusy)
                        .foregroundStyle(WriteRightTheme.secondary)
                        .accessibilityIdentifier("auth-resend")
                    }
                }

                if let error = model.authErrorMessage {
                    Text(error).font(.footnote).foregroundStyle(.red)
                        .accessibilityIdentifier("auth-error")
                }
            }
            .padding(24).frame(maxWidth: 520, alignment: .leading)
        }
        .frame(maxWidth: .infinity).background(WriteRightTheme.background)
        .foregroundStyle(WriteRightTheme.ink).navigationTitle("邮箱登录")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusedField = .email }
    }

    private func sendCode() async {
        if await model.requestCode(email: email) {
            codeSent = true
            resendAt = Date().addingTimeInterval(60)
            code = ""
            focusedField = .code
        }
    }

    private func verify() async {
        if await model.verifyCode(email: email, code: code) { dismiss() }
    }
}

struct AccountView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var newEmail = ""
    @State private var confirmationSent = false
    @State private var confirmingSignOut = false

    var body: some View {
        List {
            Section {
                LabeledContent("邮箱", value: model.account?.email ?? "")
                    .lineLimit(1).truncationMode(.middle)
            }
            Section {
                TextField("新邮箱", text: $newEmail)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("发送确认邮件") {
                    Task {
                        confirmationSent = await model.updateEmail(newEmail)
                        if confirmationSent { newEmail = "" }
                    }
                }.disabled(model.isAuthBusy || newEmail.isEmpty)
                if confirmationSent {
                    Text("请按确认邮件完成变更。").font(.footnote).foregroundStyle(WriteRightTheme.secondary)
                }
            }
            Section {
                Button("退出登录", role: .destructive) { confirmingSignOut = true }
            }
        }
        .listStyle(.insetGrouped).scrollContentBackground(.hidden)
        .background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
        .navigationTitle("账号").navigationBarTitleDisplayMode(.inline)
        .onChange(of: model.account) { _, account in if account == nil { dismiss() } }
        .confirmationDialog("退出当前账号？", isPresented: $confirmingSignOut, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) { Task { await model.signOut() } }
        }
        .alert("账号", isPresented: Binding(
            get: { model.authErrorMessage != nil },
            set: { if !$0 { model.authErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) { model.authErrorMessage = nil }
        } message: { Text(model.authErrorMessage ?? "") }
    }
}
