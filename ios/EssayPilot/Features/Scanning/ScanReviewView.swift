import SwiftUI
import PhotosUI
import VisionKit
import AVFoundation
import UIKit

enum ScanPurpose: String, Identifiable { case essay, task; var id: String { rawValue } }

struct ScanReviewView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    let purpose: ScanPurpose
    let part: WritingPart
    let hasEssay: Bool
    let onEssay: ([ScanPageDocument], Bool) -> Void
    let onTask: ([ScanPageDocument], String, ParsedTaskDocument?) -> Void
    @State private var pages: [ScanPageDocument] = []
    @State private var picks: [PhotosPickerItem] = []
    @State private var scanning = false
    @State private var takingPhoto = false
    @State private var busy = false
    @State private var workTask: Task<Void, Never>?
    @State private var importStatus: String?
    private var isWorking: Bool { busy || importStatus != nil }
    @State private var error: String?
    @State private var appendChoice = false
    @State private var parsed: ParsedTaskDocument?
    @State private var reviewParsed = false
    @State private var zoom: ScanPageDocument?
    @State private var highlightedLineID: UUID?
    @State private var aiPage: ScanPageDocument?
    @State private var aiResponse: ImageTranscriptionResponse?
    @State private var confirmAI = false
    @State private var reviewAI = false

    private var canCapture: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }
    private var canScanDocuments: Bool { VNDocumentCameraViewController.isSupported }
    #if DEBUG
    private var showsSample: Bool { ProcessInfo.processInfo.arguments.contains("-ui-test-scan") }
    private var privateFixture: URL? {
        guard showsSample, let path = ProcessInfo.processInfo.environment["WRITERIGHT_SCAN_FIXTURE"] else { return nil }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        return url.path.contains("/tests/private/") ? url : nil
    }
    #endif

    var body: some View {
        NavigationStack {
            List {
                if pages.isEmpty { emptyState }
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    pageSection(index: index, page: page)
                }
                .onMove { if !isWorking { pages.move(fromOffsets: $0, toOffset: $1) } }
                if let error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).foregroundStyle(.red).font(.footnote)
                        if error.contains("设置") {
                            Button("打开设置") {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                UIApplication.shared.open(url)
                            }.font(.footnote.weight(.semibold))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(WriteRightTheme.background)
            .navigationTitle(purpose == .essay ? "核对作文" : "核对题面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancelScan)
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("cancel-scan")
                }
                ToolbarItem(placement: .topBarTrailing) { EditButton().disabled(isWorking || pages.count < 2) }
                ToolbarItemGroup(placement: .bottomBar) {
                    importControls
                    Spacer()
                    if isWorking {
                        ProgressView().accessibilityLabel(importStatus ?? "正在识别")
                        if let importStatus { Text(importStatus).font(.caption) }
                    }
                    else if !pages.isEmpty { confirmControls }
                }
            }
            .confirmationDialog("用 AI 辅助转录？", isPresented: $confirmAI, titleVisibility: .visible) {
                Button("发送这一页并转录") { launchWork { await transcribeWithAI() } }
            } message: {
                Text("这一页原图将发送至服务端与 DeepSeek。AI 也可能误认或纠正原稿，需要对照核对后再使用。")
            }
            .fullScreenCover(isPresented: $reviewAI) {
                if let response = aiResponse, let page = aiPage, let image = loadImage(page) {
                    AITranscriptReview(image: image, original: page.correctedText, response: response) { text in
                        if let index = pages.firstIndex(where: { $0.id == page.id }) {
                            pages[index].correctedText = text
                            pages[index].confirmed = false
                        }
                    }
                }
            }
            .onChange(of: picks) { _, values in
                guard !values.isEmpty, importStatus == nil else { return }
                launchWork { await importPhotos(values) }
            }
            .sheet(isPresented: $scanning) {
                DocumentScanner { images in launchWork { await importCaptured(images) } }
            }
            .sheet(isPresented: $takingPhoto) {
                CameraCapture { image in launchWork { await importCaptured([image]) } }
            }
            .sheet(isPresented: $reviewParsed) {
                if let parsed {
                    ParsedTaskReview(parsed: parsed) { value in
                        onTask(confirmedPages(), pages.map(\.correctedText).joined(separator: "\n\n"), value)
                        dismiss()
                    }
                }
            }
            .sheet(item: $zoom) { page in
                if let image = loadImage(page) { ScanZoomView(image: image, lines: page.lines, highlighted: highlightedLineID) }
            }
            .confirmationDialog("现有正文如何处理？", isPresented: $appendChoice, titleVisibility: .visible) {
                Button("追加到正文") { onEssay(confirmedPages(), true); dismiss() }
                Button("替换正文", role: .destructive) { onEssay(confirmedPages(), false); dismiss() }
            }
        }
        .interactiveDismissDisabled(isWorking)
        .onDisappear { workTask?.cancel() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(purpose == .essay ? "拍下手写稿" : "拍下题目", systemImage: "camera")
        } description: {
            Text("最多 4 页。照片由 AI 阅读，发送前会告知，读图后请对照核对。")
        }
        .listRowBackground(WriteRightTheme.background)
    }

    @ViewBuilder private var importControls: some View {
        if canCapture {
            Button { launchWork { await openCamera() } } label: {
                Image(systemName: "camera").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("拍照")
            .accessibilityIdentifier("scan-camera")
            .disabled(isWorking || pages.count >= 4)
        }
        PhotosPicker(selection: $picks, maxSelectionCount: max(1, 4 - pages.count), selectionBehavior: .ordered, matching: .images) {
            Image(systemName: "photo.on.rectangle").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("从相册导入")
        .accessibilityIdentifier("scan-album")
        .disabled(isWorking || pages.count >= 4)
        if canScanDocuments {
            Button { launchWork { await openScanner() } } label: {
                Image(systemName: "doc.viewfinder").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("扫描多页")
            .accessibilityIdentifier("scan-document")
            .disabled(isWorking || pages.count >= 4)
        }
        #if DEBUG
        if showsSample {
            Button(privateFixture == nil ? "识别样例" : "识别验收图片") { launchWork { await addSample() } }
                .disabled(isWorking || pages.count >= 4)
                .accessibilityIdentifier("scan-sample")
        }
        #endif
    }

    @ViewBuilder private var confirmControls: some View {
        if purpose == .task && app.canGrade {
            Button("解析题目") { launchWork { await parse() } }.disabled(isWorking)
        }
        Button(purpose == .essay ? "确认转录" : "使用题面") { accept() }
            .fontWeight(.semibold)
            .accessibilityIdentifier("confirm-transcript")
    }

    private func pageSection(index: Int, page: ScanPageDocument) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("第 \(index + 1) 页").font(.headline)
                Spacer()
                Button { launchWork { await rotate(index) } } label: { Image(systemName: "rotate.right") }
                    .accessibilityLabel("旋转第 \(index + 1) 页").disabled(isWorking)
                Button(role: .destructive) { removePage(page.id) } label: { Image(systemName: "trash") }
                    .accessibilityLabel("删除第 \(index + 1) 页").disabled(isWorking)
            }
            if let image = loadImage(page) {
                Button { zoom = page } label: {
                    ScanPageImage(image: image, lines: page.lines, highlighted: highlightedLineID)
                        .frame(maxHeight: 240)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("放大原图")
            }
            TextEditor(text: Binding(
                get: { pages.first { $0.id == page.id }?.correctedText ?? "" },
                set: { value in
                    guard let i = pages.firstIndex(where: { $0.id == page.id }) else { return }
                    pages[i].correctedText = value
                    pages[i].confirmed = false
                }
            ))
            .font(.system(.body, design: .serif))
            .autocorrectionDisabled()
            .disabled(isWorking)
            .frame(minHeight: 160)
            .accessibilityLabel("第 \(index + 1) 页转录")
            .accessibilityIdentifier("scan-transcript-\(index)")
            if app.canGrade {
                Button(page.rawText.isEmpty ? "让 AI 读取这一页" : "重新用 AI 读图") { aiPage = page; confirmAI = true }
                    .font(.subheadline).disabled(isWorking)
                    .accessibilityIdentifier("ai-transcribe-\(index)")
            }
            if purpose == .essay {
                Text("请先让 AI 读图，再对照照片核对。保留学生原稿中的错误。")
                    .font(.footnote).foregroundStyle(WriteRightTheme.secondary)
            }
            let uncertain = page.lines.filter { $0.confidence < OCRTranscript.uncertainConfidence || $0.text == OCRTranscript.placeholder }
            if !uncertain.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("待核对 \(uncertain.count) 行").font(.subheadline.weight(.medium))
                    ForEach(uncertain) { line in
                        VStack(alignment: .leading, spacing: 6) {
                            Button {
                                highlightedLineID = line.id
                            } label: {
                                Text(line.text).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("在原图中定位这一行")
                            if !line.alternatives.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(line.alternatives, id: \.self) { candidate in
                                            Button(candidate) { replace(lineID: line.id, on: page.id, with: candidate) }
                                                .disabled(isWorking)
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(WriteRightTheme.soft, in: Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .listRowBackground(WriteRightTheme.surface)
    }

    private func removePage(_ pageID: UUID) {
        guard !isWorking, let index = pages.firstIndex(where: { $0.id == pageID }) else { return }
        do {
            try app.scanImageStore().remove(pages[index].relativePath)
            pages.remove(at: index)
        } catch {
            self.error = "这一页未能移除，请重试。"
        }
    }

    private func cancelScan() {
        workTask?.cancel()
        do {
            let store = try app.scanImageStore()
            for page in pages { try store.remove(page.relativePath) }
            dismiss()
        } catch {
            self.error = "临时图片未能完全清理，请再试一次取消。你的正文未改动。"
        }
    }

    private func launchWork(_ action: @escaping @MainActor () async -> Void) {
        guard !isWorking else { return }
        workTask?.cancel()
        workTask = Task { await action() }
    }

    private func confirmedPages() -> [ScanPageDocument] {
        pages.map { var page = $0; page.confirmed = true; return page }
    }

    private func loadImage(_ page: ScanPageDocument) -> UIImage? {
        guard let store = try? app.scanImageStore(), let url = store.url(page.relativePath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private func transcribeWithAI() async {
        guard let page = aiPage, let image = loadImage(page) else { return }
        busy = true
        defer { busy = false }
        do {
            let response = try await app.transcribeImage(ScanImageStore.normalized(image))
            try Task.checkCancellation()
            if let index = pages.firstIndex(where: { $0.id == page.id }), pages[index].rawText.isEmpty {
                pages[index].rawText = response.text
                pages[index].uncertainties = response.uncertain
                pages[index].transcriptionSource = "ai_photo"
            }
            aiResponse = response
            reviewAI = true
        } catch ImageUploadError.tooLarge {
            self.error = "这一页图片较大，请裁去无关边缘后重试。原图和现有转录已保留。"
        } catch {
            if !Task.isCancelled { self.error = "AI 转录未完成，原图和现有转录已保留。请重试或手动核对。" }
        }
    }

    private func importPhotos(_ values: [PhotosPickerItem]) async {
        guard importStatus == nil else { return }
        importStatus = "正在导入"
        error = nil
        defer { importStatus = nil; picks = [] }
        var unreadable = 0
        for (index, pick) in values.enumerated() {
            guard !Task.isCancelled else { return }
            importStatus = "正在导入 \(index + 1)/\(values.count)"
            if let data = try? await pick.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                guard !Task.isCancelled else { return }
                await add(image)
            } else if !Task.isCancelled { unreadable += 1 }
        }
        if unreadable > 0 && !Task.isCancelled { error = "有 \(unreadable) 张图片未能读取，已导入的页面会保留。请重新选择缺少的页面。" }
    }

    private func importCaptured(_ images: [UIImage]) async {
        guard importStatus == nil else { return }
        importStatus = "正在导入"
        defer { importStatus = nil }
        for (index, image) in images.enumerated() {
            guard !Task.isCancelled else { return }
            importStatus = "正在导入 \(index + 1)/\(images.count)"
            await add(image)
        }
    }

    private func add(_ image: UIImage) async {
        guard pages.count < 4 else { error = "每次最多导入 4 页。"; return }
        busy = true
        defer { busy = false }
        do {
            let owner = app.account?.userID
            let store = try app.scanImageStore()
            let data = try ScanImageStore.normalized(image)
                        try Task.checkCancellation()
            guard app.account?.userID == owner else { return }
            let id = UUID()
            let path = try store.save(data: data, id: id)
            pages.append(.init(id: id, relativePath: path, rawText: "", correctedText: "", lines: [], confirmed: false, transcriptionSource: "ai_photo"))
        } catch {
            if !Task.isCancelled { self.error = "未能识别这一页，请重试。" }
        }
    }

    private func addSample() async {
        #if DEBUG
        if let fixture = privateFixture {
            guard let image = UIImage(contentsOfFile: fixture.path) else {
                error = "验收图片未能读取，请检查私有样本路径。"
                return
            }
            await add(image)
            return
        }
        #endif
        let sentence = purpose == .essay
            ? "Dear Alex, I would like to invite you."
            : "Write an essay about the chart below."
        guard let data = try? ScanSampleImage.jpeg(text: sentence), let image = UIImage(data: data) else {
            error = "样例图片未能生成。"
            return
        }
        await add(image)
    }

    private func rotate(_ index: Int) async {
        guard pages.indices.contains(index), let image = loadImage(pages[index]) else { return }
        busy = true
        defer { busy = false }
        do {
            let owner = app.account?.userID
            let store = try app.scanImageStore()
            let data = try ScanImageStore.normalized(image, rotation: true)
                        try Task.checkCancellation()
            guard app.account?.userID == owner else { return }
            pages[index].relativePath = try store.save(data: data, id: pages[index].id)
            pages[index].lines = []
            pages[index].rawText = ""
            pages[index].correctedText = ""
            pages[index].confirmed = false
            highlightedLineID = nil
        } catch {
            if !Task.isCancelled { self.error = "旋转识别未完成，请重试。" }
        }
    }

    private func replace(lineID: UUID, on pageID: UUID, with candidate: String) {
        guard let pageIndex = pages.firstIndex(where: { $0.id == pageID }),
              let lineIndex = pages[pageIndex].lines.firstIndex(where: { $0.id == lineID }) else { return }
        guard let updated = OCRLayout.replacingCandidate(
            in: pages[pageIndex].correctedText, lines: pages[pageIndex].lines,
            lineID: lineID, with: candidate, joinsWrappedLines: purpose == .essay
        ) else {
            error = "转录已有修改，请在正文中手动替换这一处，避免覆盖你的编辑。"
            return
        }
        pages[pageIndex].correctedText = updated
        pages[pageIndex].lines[lineIndex] = OCRLineDocument(
            id: pages[pageIndex].lines[lineIndex].id, text: candidate, confidence: 1,
            alternatives: pages[pageIndex].lines[lineIndex].alternatives,
            x: pages[pageIndex].lines[lineIndex].x, y: pages[pageIndex].lines[lineIndex].y,
            width: pages[pageIndex].lines[lineIndex].width, height: pages[pageIndex].lines[lineIndex].height
        )
        pages[pageIndex].confirmed = false
        highlightedLineID = lineID
    }

    private func openCamera() async {
        guard canCapture else { error = "这台设备不能拍照，请从相册导入。"; return }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        guard !Task.isCancelled else { return }
        if allowed { takingPhoto = true } else { error = "请在系统设置中允许相机访问。" }
    }

    private func openScanner() async {
        guard canScanDocuments else { error = "这台设备不能扫描多页，请改用拍照或相册。"; return }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        guard !Task.isCancelled else { return }
        if allowed { scanning = true } else { error = "请在系统设置中允许相机访问。" }
    }

    private func parse() async {
        busy = true
        defer { busy = false }
        do {
            guard pages.allSatisfy({ !$0.correctedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                self.error = "请先逐页让 AI 读图并核对题面。"
                return
            }
            let images = try pages.compactMap(loadImage).map { try ScanImageStore.normalized($0) }
            let response = try await app.parseTask(part: part, text: pages.map(\.correctedText).joined(separator: "\n\n"), images: images)
            try Task.checkCancellation()
            parsed = response.parsed
            reviewParsed = true
        } catch ImageUploadError.tooLarge {
            self.error = "题面图片较大，请裁去无关边缘后重试，或使用核对后的文字题面。"
        } catch {
            if !Task.isCancelled { self.error = "解析未完成，可重试或直接使用核对后的题面。" }
        }
    }

    private func accept() {
        if pages.contains(where: { $0.correctedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || OCRTranscript.containsUnresolved($0.correctedText) }) {
            error = "请先替换待确认的识别文字。"
            return
        }
        if purpose == .essay && hasEssay { appendChoice = true }
        else if purpose == .essay { onEssay(confirmedPages(), false); dismiss() }
        else { onTask(confirmedPages(), pages.map(\.correctedText).joined(separator: "\n\n"), nil); dismiss() }
    }
}

private struct ScanPageImage: View {
    let image: UIImage
    let lines: [OCRLineDocument]
    let highlighted: UUID?

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay { highlight }
            .accessibilityHidden(true)
    }

    @ViewBuilder private var highlight: some View {
        if let line = lines.first(where: { $0.id == highlighted }) {
            GeometryReader { geo in
                let fitted = fittedRect(imageSize: image.size, in: geo.size)
                let box = CGRect(
                    x: fitted.minX + line.x * fitted.width,
                    y: fitted.minY + (1 - line.y - line.height) * fitted.height,
                    width: max(2, line.width * fitted.width),
                    height: max(2, line.height * fitted.height)
                )
                RoundedRectangle(cornerRadius: 3)
                    .stroke(WriteRightTheme.accent, lineWidth: 2)
                    .background(WriteRightTheme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 3))
                    .frame(width: box.width, height: box.height)
                    .position(x: box.midX, y: box.midY)
            }
        }
    }

    private func fittedRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, container.width > 0, container.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (container.width - size.width) / 2, y: (container.height - size.height) / 2, width: size.width, height: size.height)
    }
}

struct ParsedTaskReview: View {
    @Environment(\.dismiss) private var dismiss
    @State var parsed: ParsedTaskDocument
    @State private var checkedUncertain = false
    let accept: (ParsedTaskDocument) -> Void
    var body: some View {
        NavigationStack {
            Form {
                Section("要求") {
                    ForEach($parsed.requiredPoints, id: \.id) { $point in
                        TextField("写作要求", text: $point.description, axis: .vertical)
                    }
                }
                if !parsed.chartFacts.isEmpty {
                    Section("图表数据") {
                        ForEach($parsed.chartFacts) { $fact in
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("类别", text: $fact.label)
                                HStack {
                                    TextField("时期", text: Binding(get: { fact.period ?? "" }, set: { fact.period = $0.isEmpty ? nil : $0 }))
                                    TextField("数值", text: $fact.value)
                                    TextField("单位", text: $fact.unit)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                if !parsed.uncertainFields.isEmpty {
                    Section("待核对") {
                        ForEach(parsed.uncertainFields, id: \.self) { Text($0).font(.subheadline) }
                        Toggle("已核对并修正以上信息", isOn: $checkedUncertain)
                    }
                }
            }
            .navigationTitle("确认题目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认") {
                        parsed.uncertainFields = []
                        accept(parsed)
                    }
                    .disabled(!parsed.uncertainFields.isEmpty && !checkedUncertain)
                    .accessibilityIdentifier("confirm-parsed-task")
                }
            }
        }
    }
}

private struct DocumentScanner: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let accept: ([UIImage]) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camera = VNDocumentCameraViewController()
        camera.delegate = context.coordinator
        return camera
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let remaining = 4
            parent.accept((0..<min(remaining, scan.pageCount)).map { scan.imageOfPage(at: $0) })
            parent.dismiss()
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { parent.dismiss() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { parent.dismiss() }
    }
}

struct CameraCapture: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let accept: (UIImage) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.accept(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

struct ScanZoomView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let lines: [OCRLineDocument]
    let highlighted: UUID?
    @State private var scale = 1.0
    @State private var base = 1.0
    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                ScanPageImage(image: image, lines: lines, highlighted: highlighted)
                    .frame(width: 350 * scale)
            }
            .gesture(MagnifyGesture().onChanged { scale = min(4, max(1, base * $0.magnification)) }.onEnded { _ in base = scale })
            .toolbar { Button("完成") { dismiss() } }
        }
    }
}

private struct AITranscriptReview: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let original: String
    let response: ImageTranscriptionResponse
    let accept: (String) -> Void
    @State private var candidate: String
    @State private var checked = false
    @State private var showingOriginal = false
    @FocusState private var candidateFocused: Bool

    init(image: UIImage, original: String, response: ImageTranscriptionResponse, accept: @escaping (String) -> Void) {
        self.image = image; self.original = original; self.response = response; self.accept = accept
        _candidate = State(initialValue: response.text)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { showingOriginal = true } label: {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                    }
                    .buttonStyle(.plain).accessibilityLabel("放大原图")
                    .accessibilityIdentifier("ai-transcript-original")
                    Text("请对照原图检查数字、拼写和语法错误是否被保留。AI 可能无意改写，疑字不能当作写作错误。")
                        .font(.footnote).foregroundStyle(WriteRightTheme.secondary)
                }
                if !original.isEmpty { Section("现有核对稿") { Text(original).font(.system(.body, design: .serif)) } }
                Section("AI 转录 · 可修改") {
                    TextEditor(text: $candidate).frame(minHeight: 240).autocorrectionDisabled()
                        .font(.system(.body, design: .serif))
                        .focused($candidateFocused)
                        .accessibilityLabel("AI 转录，可修改")
                        .accessibilityIdentifier("ai-transcript-candidate")
                }
                if !response.uncertain.isEmpty {
                    Section("待核对") {
                        ForEach(Array(response.uncertain.enumerated()), id: \.offset) { _, item in Text(item) }
                    }
                }
                Section {
                    Toggle("已对照原图核对，保留了原稿错误", isOn: $checked)
                        .accessibilityIdentifier("ai-transcript-checked")
                }
            }
            .scrollContentBackground(.hidden).background(WriteRightTheme.background)
            .foregroundStyle(WriteRightTheme.ink)
            .sheet(isPresented: $showingOriginal) { ScanZoomView(image: image, lines: [], highlighted: nil) }
            .navigationTitle("核对 AI 转录").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { candidateFocused = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 16) {
                    Button("返回") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .frame(minWidth: 60, minHeight: 44)
                        .accessibilityIdentifier("cancel-ai-transcript")
                    Button("使用这份转录") { accept(candidate); dismiss() }
                        .buttonStyle(MainActionStyle())
                        .accessibilityIdentifier("adopt-ai-transcript")
                        .disabled(!checked || candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || OCRTranscript.containsUnresolved(candidate))
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(WriteRightTheme.background)
            }
        }
        .interactiveDismissDisabled()
    }
}
