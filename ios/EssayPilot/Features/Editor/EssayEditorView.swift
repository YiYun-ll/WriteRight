import SwiftUI

struct EssayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var model: EssayEditorModel
    @State private var topicExpanded: Bool
    @State private var isSubmitting = false
    @State private var submitError: String?
    private let onPhotos: () -> Void
    private enum Field: Hashable { case title, prompt, requirements, body }
    @FocusState private var focusedField: Field?

    init(document: DraftDocument, repository: any WritingRepository, didSave: @escaping () -> Void, onPhotos: @escaping () -> Void = {}) {
        self.onPhotos = onPhotos
        _model = StateObject(wrappedValue: EssayEditorModel(document: document, repository: repository, didSave: didSave))
        _topicExpanded = State(initialValue: document.task.prompt.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    topicSection
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("正文").font(.title3.weight(.semibold))
                            Spacer()
                            if ["ocr", "ai_photo"].contains(model.document.source) {
                                Text(model.document.source == "ai_photo" ? "AI 读图核对稿" : "历史转录").font(.caption).foregroundStyle(WriteRightTheme.secondary)
                            }
                            Text("参考词数 \(model.wordCount)")
                                .font(.caption.monospacedDigit()).foregroundStyle(WriteRightTheme.secondary)
                                .accessibilityHint("缩略词、连字符词和数字分别计为一个词，仅供参考")
                                .accessibilityIdentifier("word-count")
                        }
                        if model.body.isEmpty {
                            Button("导入作文照片", systemImage: "photo") { openPhotos() }
                                .font(.subheadline).frame(minHeight: 44)
                                .accessibilityIdentifier("import-essay-photo")
                        }
                        ZStack(alignment: .topLeading) {
                            if model.body.isEmpty {
                                Text("写下你的作文…").foregroundStyle(WriteRightTheme.secondary)
                                    .padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                            }
                            TextEditor(text: $model.body)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .serif)).lineSpacing(7)
                                .scrollContentBackground(.hidden).focused($focusedField, equals: .body)
                                .frame(minHeight: 350).accessibilityLabel("作文正文")
                                .accessibilityIdentifier("essay-body")
                        }.padding(16).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                    }
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
            .navigationTitle(model.part.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if model.save() { dismiss() }
                    } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel("保存并返回").accessibilityIdentifier("close-editor")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { focusedField = nil }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { if model.save() { dismiss() } }
                        .fontWeight(.semibold).accessibilityIdentifier("finish-editing")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("用照片新建批改", systemImage: "camera") { openPhotos() }
                        .accessibilityIdentifier("open-scan")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if let error = model.saveError {
                        HStack {
                            Text(error).font(.footnote)
                            Spacer()
                            Button("重试") { model.save() }
                        }.foregroundStyle(.red)
                    }
                    if let submitError {
                        Text(submitError).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("submit-error")
                    }
                    if let reason = submitBlockedReason {
                        Text(reason).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("submit-blocked")
                    } else if !model.taskConfirmed && appModel.canGrade {
                        Text("题目未确认时不估总分。").font(.footnote).foregroundStyle(WriteRightTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if appModel.canGrade {
                        Button {
                            guard model.save() else { return }
                            isSubmitting = true; submitError = nil
                            Task {
                                let job = await appModel.submitGrading(model.document)
                                isSubmitting = false
                                if job != nil { dismiss(); return }
                                // The app-wide alert sits under this full-screen editor, so failures are shown inline.
                                submitError = appModel.errorMessage ?? appModel.authErrorMessage ?? "这次未能提交，原稿已保存，可以稍后重试。"
                                appModel.errorMessage = nil
                            }
                        } label: {
                            Group {
                                if isSubmitting { ProgressView().tint(.white) }
                                else { Text("提交批改") }
                            }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MainActionStyle())
                        .disabled(isSubmitting || submitBlockedReason != nil || model.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("submit-grading")
                    }
                }
                .padding().background(WriteRightTheme.background)
            }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { model.save() } }
        .onDisappear { model.finishEditing() }
        .interactiveDismissDisabled(model.saveError != nil)
    }

    private var submitBlockedReason: String? {
        if OCRTranscript.containsUnresolved(model.body) { return "请先替换待确认的识别文字。" }
        if ["ocr", "ai_photo"].contains(model.document.source) && !model.document.transcriptionConfirmed { return "请先完成转录核对。" }
        return nil
    }

    private func openPhotos() {
        focusedField = nil
        if model.save() { onPhotos() }
    }

    private var topicSection: some View {
        DisclosureGroup(isExpanded: $topicExpanded) {
            VStack(alignment: .leading, spacing: 20) {
                TextField("题目名称（选填）", text: $model.title)
                    .font(.headline).focused($focusedField, equals: .title).accessibilityIdentifier("task-title")
                VStack(alignment: .leading, spacing: 10) {
                    Text("题面").font(.subheadline.weight(.medium))
                    TextField("粘贴或输入完整题目", text: $model.prompt, axis: .vertical)
                        .lineLimit(4...12).textInputAutocapitalization(.sentences)
                        .focused($focusedField, equals: .prompt)
                        .accessibilityIdentifier("task-prompt")
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("要点").font(.subheadline.weight(.medium))
                    TextField("每行一条，可选填", text: $model.requirements, axis: .vertical)
                        .lineLimit(2...8).focused($focusedField, equals: .requirements).accessibilityIdentifier("task-requirements")
                }
                Button {
                    focusedField = nil; model.confirmTask()
                    if model.taskConfirmed { withAnimation { topicExpanded = false } }
                } label: {
                    Label(model.taskConfirmed ? "已确认" : "确认题目", systemImage: model.taskConfirmed ? "checkmark.circle.fill" : "checkmark")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                        .background(WriteRightTheme.soft, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).disabled(!model.canConfirm).opacity(model.canConfirm ? 1 : 0.45)
                    .accessibilityIdentifier("confirm-task")
            }.padding(.top, 20)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("题目").font(.headline)
                    if !topicExpanded {
                        Text(model.document.task.displayTitle).font(.subheadline)
                            .foregroundStyle(WriteRightTheme.secondary).lineLimit(2)
                    }
                }
                Spacer()
                if model.taskConfirmed {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(WriteRightTheme.accent)
                        .accessibilityLabel("题目已确认").accessibilityIdentifier("task-confirmed")
                }
            }
        }.padding(20).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 22))
    }
}
