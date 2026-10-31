import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct PhotoPracticeView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @StateObject private var model: PhotoPracticeModel
    @State private var taskPicks: [PhotosPickerItem] = []
    @State private var essayPicks: [PhotosPickerItem] = []
    @State private var cameraRole: PhotoPracticeModel.Role?
    @State private var login = false
    @State private var report: GradingReportDocument?
    @State private var zoom: ScanPageDocument?
    @FocusState private var editing: Bool

    init(app: AppModel, draft: DraftDocument? = nil) { _model = StateObject(wrappedValue: PhotoPracticeModel(app: app, draft: draft)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if model.jobID != nil { progressPage } else { upload }
                    if let error = model.error {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.subheadline).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("photo-error")
                    }
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
            .navigationTitle(model.jobID == nil ? "照片批改" : currentJob?.status == .completed ? "这一篇的回信" : "等这一页被读懂")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(model.jobID == nil ? "保存并返回" : "先去做别的") {
                    if model.jobID == nil && (!model.taskPages.isEmpty || !model.essayPages.isEmpty) && model.saveDraft() == nil { return }
                    model.cancel(); dismiss()
                }.disabled(model.isWorking) }
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    if ProcessInfo.processInfo.arguments.contains("-ui-test-photos") && model.jobID == nil {
                        Button("载入样例") {
                            model.begin("正在导入样例照片") {
                                if let data = try? ScanSampleImage.jpeg(text: "I has a book."), let image = UIImage(data: data) {
                                    if model.taskPages.isEmpty { await model.add([image], role: .task) }
                                    await model.add([image], role: .essay)
                                }
                            }
                        }.disabled(model.isWorking).accessibilityIdentifier("photo-load-sample")
                    }
                }
                #endif
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("收起键盘") { editing = false } }
            }
            .safeAreaInset(edge: .bottom) { actionBar }
            .sheet(isPresented: $login) { NavigationStack { LoginView().toolbar { Button("返回") { login = false } } } }
            .onChange(of: app.account?.userID) { old, value in
                if old != nil && old != value { model.cancel(); dismiss() }
                else if value != nil { login = false }
            }
            .fullScreenCover(item: $report) { GradingReportView(document: $0) }
            .sheet(item: $cameraRole) { role in
                CameraCapture { image in model.begin("正在导入照片") { await model.add([image], role: role) } }
            }
            .sheet(item: $zoom) { page in
                if let image = model.image(page) { ScanZoomView(image: image, lines: [], highlighted: nil) }
            }
            .onChange(of: taskPicks) { _, values in importPhotos(values, role: .task) }
            .onChange(of: essayPicks) { _, values in importPhotos(values, role: .essay) }

            .onDisappear { model.cancel() }
            .interactiveDismissDisabled(model.isWorking)
        }
    }

    private var upload: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("写过的每一页，都值得认真读。")
                    .font(.system(.title2, design: .serif))
                Text("把题目和写好的作文分开放好，直接看图批改。")
                    .font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
            }
            partPicker.disabled(model.isWorking).accessibilityIdentifier("photo-part")
            photoSection(.task, title: "题目与图表", detail: "包含完整指令、图表和单位；没有题图也可以继续。")
            photoSection(.essay, title: "作文原稿", detail: "每页拍清楚，按阅读顺序选择，最多 4 张。")
            Text(model.taskPages.isEmpty ? "未附题图时只做语言反馈，不估总分。" : "题目和作文会一起交给 AI。看不清的内容会明确指出，不把识图疑点当成你的错误。")
                .font(.footnote).foregroundStyle(WriteRightTheme.secondary)
        }
    }

    @ViewBuilder private var partPicker: some View {
        if typeSize.isAccessibilitySize {
            Picker("作文类型", selection: $model.part) {
                ForEach(WritingPart.allCases) { Text("\($0.title) · \($0.maximumScore)分").tag($0) }
            }.pickerStyle(.menu)
        } else {
            Picker("作文类型", selection: $model.part) {
                ForEach(WritingPart.allCases) { Text("\($0.title) · \($0.maximumScore)分").tag($0) }
            }.pickerStyle(.segmented)
        }
    }

    private func photoSection(_ role: PhotoPracticeModel.Role, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text(title).font(.system(.title3, design: .serif)); Spacer(); Text("\(model.pages(role).count)/4").font(.caption.monospacedDigit()) }
            Text(detail).font(.subheadline).foregroundStyle(WriteRightTheme.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(Array(model.pages(role).enumerated()), id: \.element.id) { index, page in
                HStack(spacing: 14) {
                    if let image = model.image(page) {
                        Button { zoom = page } label: { Image(uiImage: image).resizable().scaledToFit().frame(width: 60, height: 80).background(WriteRightTheme.background) }
                            .buttonStyle(.plain).accessibilityLabel("放大\(title)第\(index + 1)页")
                    }
                    Text("第 \(index + 1) 页").font(.subheadline)
                    Spacer(minLength: 0)
                    Menu {
                        Button("向前移") { model.move(page, role: role, offset: -1) }.disabled(index == 0)
                        Button("向后移") { model.move(page, role: role, offset: 1) }.disabled(index == model.pages(role).count - 1)
                        Button("向右旋转") { model.begin("正在旋转照片") { await model.rotate(page, role: role) } }
                        Button("移除", role: .destructive) { model.remove(page, role: role) }
                    } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("\(title)第\(index + 1)页操作").disabled(model.isWorking)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { album(role); camera(role) }
                VStack(alignment: .leading, spacing: 12) { album(role); camera(role) }
            }
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 16))
    }
    private func album(_ role: PhotoPracticeModel.Role) -> some View {
        PhotosPicker(selection: role == .task ? $taskPicks : $essayPicks, maxSelectionCount: max(1, 4 - model.pages(role).count), selectionBehavior: .ordered, matching: .images) {
            Label("从相册选择", systemImage: "photo.on.rectangle").frame(minHeight: 44)
        }.disabled(model.isWorking || model.pages(role).count >= 4)
            .accessibilityIdentifier("photo-album-" + role.rawValue)
    }
    @ViewBuilder private func camera(_ role: PhotoPracticeModel.Role) -> some View {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            Button {
                model.begin("正在打开相机") {
                    let allowed = await AVCaptureDevice.requestAccess(for: .video)
                    guard !Task.isCancelled else { return }
                    if allowed { cameraRole = role } else { model.error = "请在系统设置中允许相机访问，或改用相册。" }
                }
            } label: { Label("拍一张", systemImage: "camera").frame(minHeight: 44) }
                .disabled(model.isWorking || model.pages(role).count >= 4)
        }
    }
    private func importPhotos(_ values: [PhotosPickerItem], role: PhotoPracticeModel.Role) {
        guard !values.isEmpty, !model.isWorking else { return }
        model.begin("正在导入照片") {
            defer { if role == .task { taskPicks = [] } else { essayPicks = [] } }
            var failed = 0
            for value in values {
                guard !Task.isCancelled else { return }
                if let data = try? await value.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    guard !Task.isCancelled else { return }
                    await model.add([image], role: role)
                } else { failed += 1 }
            }
            if failed > 0 { model.error = "有 \(failed) 张照片未能读取，请补选缺少的页面。" }
        }
    }

    private var currentJob: GradingJobDocument? { app.gradingJobs.first { $0.id == model.jobID } }
    private var progressPage: some View {
        VStack(alignment: .leading, spacing: 24) {
            ReadingProgressView(status: currentJob?.status, stage: currentJob?.stage ?? .evaluate,
                connectionIssue: model.jobID.flatMap { app.gradingConnectionIssues[$0] },
                retry: currentJob?.status == .failed ? { if let job = currentJob { Task { await app.retryGrading(job) } } } : nil)
            if let result = app.gradingReports.first(where: { $0.jobID == model.jobID }) {
                Button("看看这次的建议") { report = result }.buttonStyle(MainActionStyle()).accessibilityIdentifier("photo-open-report")
            }
            if !model.taskPages.isEmpty {
                Text("这次的题目").font(.system(.title3, design: .serif))
                ForEach(model.taskPages) { page in thumbnail(page) }
            }
            Text("你的原稿").font(.system(.title3, design: .serif))
            ForEach(model.essayPages) { page in thumbnail(page) }
        }
    }
    private func thumbnail(_ page: ScanPageDocument) -> some View {
        Button { zoom = page } label: {
            if let image = model.image(page) { Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 240) }
        }.buttonStyle(.plain).accessibilityLabel("放大原图")
    }
    private var actionBar: some View {
        VStack(spacing: 12) {
            if model.isWorking {
                if model.isSubmitting {
                    ReadingProgressView(status: nil, stage: .evaluate, uploadPhase: app.photoUploadPhase)
                } else {
                    HStack(spacing: 12) { ProgressView(); Text(model.progress).font(.subheadline) }.padding(16)
                }
            } else if model.jobID == nil {
                if !app.canGrade {
                    if app.canAuthenticate { Button("登录后开始批改") { login = true }.buttonStyle(MainActionStyle()).accessibilityIdentifier("photo-login") }
                    else { Text("云端连接暂不可用，请稍后再试。照片可保存在草稿中。").font(.footnote) }
                } else {
                    Text("点击后，照片将保存在你的云端私有空间，并发送给 DeepSeek 用于批改与报告回看。")
                        .font(.footnote).foregroundStyle(WriteRightTheme.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("开始看图批改") { model.begin("正在整理照片") { await model.submit() } }
                        .buttonStyle(MainActionStyle()).disabled(!model.canSubmit).accessibilityIdentifier("photo-submit")
                }
            }
        }.frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.vertical, model.jobID == nil ? 14 : 0).background(WriteRightTheme.background)
    }
}
