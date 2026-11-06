import Combine
import Foundation
import UIKit

@MainActor final class PhotoPracticeModel: ObservableObject {
    enum Role: String, Identifiable { case task, essay; var id: String { rawValue } }
    @Published var title: String
    @Published var taskText: String
    @Published var essayText: String
    @Published var taskMode: PracticeInputMode
    @Published var answerMode: PracticeInputMode
    @Published var referenceTranslation: String
    @Published var part: WritingPart
    @Published private(set) var taskPages: [ScanPageDocument]
    @Published private(set) var essayPages: [ScanPageDocument]
    @Published var error: String?
    @Published private(set) var isWorking = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var progress = ""
    @Published private(set) var jobID: UUID?
    private let app: AppModel
    private var store: ScanImageStore?
    private var subscriptions = Set<AnyCancellable>()
    private var operation: Task<Void, Never>?
    private var document: DraftDocument
    private var retainedIDs: Set<UUID> = []
    private var initialTaskPages: [UUID] = []
    private let initialOwner: UUID?

    init(app: AppModel, draft: DraftDocument? = nil) {
        self.app = app; store = try? app.scanImageStore(); initialOwner = app.account?.userID
        document = draft ?? DraftDocument(id: UUID(), task: .empty(part: .a), body: "", source: "photos", transcriptionConfirmed: false, createdAt: .now, updatedAt: .now)
        title = document.task.title; taskText = document.task.prompt; essayText = document.body
        taskMode = document.resolvedTaskMode; answerMode = document.resolvedAnswerMode
        referenceTranslation = document.task.referenceTranslation ?? ""
        part = document.task.part; taskPages = document.task.sourcePages ?? []; essayPages = document.pages ?? []
        retainedIDs = Set((taskPages + essayPages).map(\.id)); initialTaskPages = taskPages.map(\.id)
        Publishers.CombineLatest4($part, $referenceTranslation, $taskMode, $answerMode).dropFirst()
            .debounce(for: .milliseconds(450), scheduler: RunLoop.main)
            .sink { [weak self] _ in _ = self?.saveDraft() }.store(in: &subscriptions)
        Publishers.CombineLatest3($title, $taskText, $essayText).dropFirst()
            .debounce(for: .milliseconds(450), scheduler: RunLoop.main)
            .sink { [weak self] _ in _ = self?.saveDraft() }.store(in: &subscriptions)
        if let submission = app.submissions.filter({ document.matches($0) }).max(by: { $0.submittedAt < $1.submittedAt }) {
            jobID = app.gradingJobs.first { $0.submissionID == submission.id }?.id
        }
    }
    var hasAnswer: Bool { answerMode == .photos ? !essayPages.isEmpty : !essayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasTask: Bool { taskMode == .photos ? !taskPages.isEmpty : !taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasContent: Bool { !taskPages.isEmpty || !essayPages.isEmpty || !taskText.isEmpty || !essayText.isEmpty || !title.isEmpty }
    var canSubmit: Bool { hasAnswer && !isWorking }
    func mode(_ role: Role) -> PracticeInputMode { role == .task ? taskMode : answerMode }
    func startAnother(keepAnswer: Bool) {
        document.id = UUID(); document.createdAt = .now; document.updatedAt = .now; jobID = nil
        if !keepAnswer { essayText = ""; essayPages = [] }
        _ = saveDraft()
    }
    func image(_ page: ScanPageDocument) -> UIImage? {
        guard let url = store?.url(page.relativePath) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    func pages(_ role: Role) -> [ScanPageDocument] { role == .task ? taskPages : essayPages }
    private func setPages(_ pages: [ScanPageDocument], role: Role) {
        if role == .task { taskPages = pages } else { essayPages = pages }
    }
    func begin(_ label: String, action: @escaping @MainActor () async -> Void) {
        guard !isWorking else { return }
        isWorking = true; progress = label; error = nil
        operation = Task { await action(); isWorking = false }
    }
    func add(_ images: [UIImage], role: Role) async {
        guard let store, jobID == nil else { return }
        do {
            for image in images {
                try Task.checkCancellation()
                var current = pages(role)
                guard current.count < 4 else { error = "每类最多 4 张，已选照片都还在。"; return }
                let data = try ScanImageStore.normalized(image)
                let id = UUID(); let path = try store.save(data: data, id: id)
                current.append(.init(id: id, relativePath: path, rawText: "", correctedText: "", lines: [], confirmed: false, transcriptionSource: "direct_photo"))
                setPages(current, role: role)
                _ = saveDraft()
            }
        } catch { if !Task.isCancelled { self.error = "这张照片没能放好，请重新选择。" } }
    }
    func remove(_ page: ScanPageDocument, role: Role) {
        guard !isWorking, jobID == nil else { return }
        do {
            if !retainedIDs.contains(page.id) { try store?.remove(page.relativePath) }
            setPages(pages(role).filter { $0.id != page.id }, role: role)
            _ = saveDraft()
        } catch { self.error = "照片暂时未能移除，请重试。" }
    }
    func move(_ page: ScanPageDocument, role: Role, offset: Int) {
        guard !isWorking, jobID == nil else { return }
        var current = pages(role)
        guard let index = current.firstIndex(where: { $0.id == page.id }), current.indices.contains(index + offset) else { return }
        current.swapAt(index, index + offset); setPages(current, role: role)
        _ = saveDraft()
    }
    func rotate(_ page: ScanPageDocument, role: Role) async {
        guard let store, let image = image(page), let index = pages(role).firstIndex(where: { $0.id == page.id }) else { return }
        do {
            let data = try ScanImageStore.normalized(image, rotation: true)
            try Task.checkCancellation()
            let id = UUID(); let path = try store.save(data: data, id: id)
            var current = pages(role)
            current[index] = .init(id: id, relativePath: path, rawText: "", correctedText: "", lines: [], confirmed: false, transcriptionSource: "direct_photo")
            if !retainedIDs.contains(page.id) { try store.remove(page.relativePath) }
            setPages(current, role: role)
            _ = saveDraft()
        } catch { if !Task.isCancelled { self.error = "照片未能旋转，原图还在，请重试。" } }
    }
    @discardableResult func saveDraft() -> DraftDocument? {
        if jobID != nil { return app.drafts.first { $0.id == document.id } ?? document }
        guard hasContent || app.drafts.contains(where: { $0.id == document.id }) else { return nil }
        guard initialOwner == nil || initialOwner == app.account?.userID else { return nil }
        var copied: [String] = []
        var destination: ScanImageStore?
        do {
            guard let repository = app.repository, let store else { throw LocalStoreError.unavailable }
            let target = try app.scanImageStore(); destination = target
            let movesStore = target.root.resolvingSymlinksInPath().standardizedFileURL.path != store.root.resolvingSymlinksInPath().standardizedFileURL.path
            if movesStore {
                for page in taskPages + essayPages {
                    let data = try Data(contentsOf: store.url(page.relativePath)!)
                    copied.append(try target.save(data: data, id: page.id))
                }
            }
            if taskPages.map(\.id) != initialTaskPages { document.task.id = UUID(); document.task.photoFingerprint = nil }
            if document.task.prompt != taskText || document.task.part != part || document.taskInputMode != taskMode {
                document.task.revision += 1; document.task.confirmedAt = nil
            }
            document.task.title = title
            document.task.referenceTranslation = part == .translation && !referenceTranslation.isEmpty ? referenceTranslation : nil
            document.task.part = part; document.task.sourcePages = taskPages; document.task.prompt = taskText
            if taskMode == .text && !taskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { document.task.confirmedAt = document.task.confirmedAt ?? .now }
            else { document.task.confirmedAt = nil }
            document.taskInputMode = taskMode; document.answerInputMode = answerMode
            document.pages = essayPages; document.body = essayText; document.source = "practice"; document.transcriptionConfirmed = answerMode == .text; document.updatedAt = .now
            try repository.save(document)
            if movesStore {
                for page in taskPages + essayPages where !retainedIDs.contains(page.id) { try? store.remove(page.relativePath) }
                self.store = target
            }
            retainedIDs.formUnion((taskPages + essayPages).map(\.id)); initialTaskPages = taskPages.map(\.id); app.refresh()
            return document
        } catch {
            for path in copied { try? destination?.remove(path) }
            self.error = "稿件未能保存，照片仍在本页，请重试。"; return nil
        }
    }
    func submit() async {
        guard hasAnswer, let draft = saveDraft()?.activePracticeDraft else { return }
        isSubmitting = true; defer { isSubmitting = false }
        if (draft.pages ?? []).isEmpty && (draft.task.sourcePages ?? []).isEmpty {
            jobID = await app.submitGrading(draft)?.id
        } else { jobID = await app.submitPhotoGrading(draft)?.id }
        if jobID == nil {
            // Shown here; leaving it on the app would pop the same alert again after this page closes.
            error = app.errorMessage ?? "这次未能提交，照片已保存，可以稍后继续。"; app.errorMessage = nil
        }
    }
    func cancel() {
        operation?.cancel()
        for page in taskPages + essayPages where !retainedIDs.contains(page.id) { try? store?.remove(page.relativePath) }
    }
}
