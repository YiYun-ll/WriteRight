import Combine
import Foundation
import UIKit

@MainActor final class PhotoPracticeModel: ObservableObject {
    enum Role: String, Identifiable { case task, essay; var id: String { rawValue } }
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
    private var operation: Task<Void, Never>?
    private var document: DraftDocument
    private var retainedIDs: Set<UUID> = []
    private var initialTaskPages: [UUID] = []
    private let initialOwner: UUID?

    init(app: AppModel, draft: DraftDocument? = nil) {
        self.app = app; store = try? app.scanImageStore(); initialOwner = app.account?.userID
        document = draft ?? DraftDocument(id: UUID(), task: .empty(part: .a), body: "", source: "photos", transcriptionConfirmed: false, createdAt: .now, updatedAt: .now)
        part = document.task.part; taskPages = document.task.sourcePages ?? []; essayPages = document.pages ?? []
        retainedIDs = Set((taskPages + essayPages).map(\.id)); initialTaskPages = taskPages.map(\.id)
        if let submission = app.submissions.filter({ $0.draftID == document.id }).max(by: { $0.submittedAt < $1.submittedAt }) {
            jobID = app.gradingJobs.first { $0.submissionID == submission.id }?.id
        }
    }
    var canSubmit: Bool { !essayPages.isEmpty && !isWorking }
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
            }
        } catch { if !Task.isCancelled { self.error = "这张照片没能放好，请重新选择。" } }
    }
    func remove(_ page: ScanPageDocument, role: Role) {
        guard !isWorking, jobID == nil else { return }
        do {
            if !retainedIDs.contains(page.id) { try store?.remove(page.relativePath) }
            setPages(pages(role).filter { $0.id != page.id }, role: role)
        } catch { self.error = "照片暂时未能移除，请重试。" }
    }
    func move(_ page: ScanPageDocument, role: Role, offset: Int) {
        guard !isWorking, jobID == nil else { return }
        var current = pages(role)
        guard let index = current.firstIndex(where: { $0.id == page.id }), current.indices.contains(index + offset) else { return }
        current.swapAt(index, index + offset); setPages(current, role: role)
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
        } catch { if !Task.isCancelled { self.error = "照片未能旋转，原图还在，请重试。" } }
    }
    @discardableResult func saveDraft() -> DraftDocument? {
        if jobID != nil { return app.drafts.first { $0.id == document.id } ?? document }
        guard !taskPages.isEmpty || !essayPages.isEmpty else { return nil }
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
            document.task.part = part; document.task.sourcePages = taskPages; document.task.prompt = ""; document.task.requirements = []; document.task.confirmedAt = nil
            document.pages = essayPages; document.body = ""; document.source = "photos"; document.transcriptionConfirmed = false; document.updatedAt = .now
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
        guard !essayPages.isEmpty, let draft = saveDraft() else { return }
        isSubmitting = true; defer { isSubmitting = false }
        jobID = await app.submitPhotoGrading(draft)?.id
        if jobID == nil { error = app.errorMessage ?? "这次未能提交，照片已保存，可以稍后继续。" }
    }
    func cancel() {
        operation?.cancel()
        for page in taskPages + essayPages where !retainedIDs.contains(page.id) { try? store?.remove(page.relativePath) }
    }
}
