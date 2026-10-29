import Combine
import Foundation

@MainActor final class AppModel: ObservableObject {
    @Published private(set) var drafts: [DraftDocument] = []
    @Published private(set) var submissions: [SubmissionDocument] = []
    @Published var errorMessage: String?
    @Published private(set) var isReady = false
    private(set) var repository: (any WritingRepository)?

    init(repository: (any WritingRepository)? = nil) {
        if let repository { self.repository = repository; refresh(); isReady = true }
        else { openStore() }
    }

    func openStore() {
        do {
            let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            // Keep the initial storage path stable when the product display name changes.
            var storePath = "JuGuang/local/writing.store"
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-ui-test-store"), arguments.indices.contains(index + 1),
               let testID = UUID(uuidString: arguments[index + 1]) {
                storePath = "JuGuang/ui-tests/\(testID.uuidString)/writing.store"
            }
            #endif
            repository = try SwiftDataWritingRepository(storeURL: root.appendingPathComponent(storePath))
            try reload(); isReady = true; errorMessage = nil
        } catch { isReady = false; errorMessage = "无法打开练习库。原有数据已保留，请重试。" }
    }

    func refresh() {
        do { try reload() } catch { errorMessage = "未能读取练习，请重试。" }
    }

    private func reload() throws {
        guard let repository else { throw LocalStoreError.unavailable }
        drafts = try repository.drafts(); submissions = try repository.submissions()
    }

    func createDraft(part: WritingPart, task: WritingTaskDocument? = nil) -> DraftDocument? {
        let document = DraftDocument(id: UUID(), task: task ?? .empty(part: part), body: "", source: "typed", transcriptionConfirmed: true, createdAt: .now, updatedAt: .now)
        do {
            guard let repository else { throw LocalStoreError.unavailable }
            try repository.save(document); try reload(); return document
        } catch { errorMessage = "未能新建草稿，请重试。"; return nil }
    }

    func delete(_ draft: DraftDocument) {
        do { try repository?.deleteDraft(id: draft.id); try reload() }
        catch { errorMessage = "未能删除草稿，请重试。" }
    }

    func exportURL() throws -> URL {
        guard let repository else { throw LocalStoreError.unavailable }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WriteRight-练习备份.json")
        try repository.exportData().write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}

@MainActor final class EssayEditorModel: ObservableObject {
    @Published var title: String
    @Published var prompt: String
    @Published var requirements: String
    @Published var body: String
    @Published private(set) var taskConfirmed: Bool
    @Published private(set) var saveError: String?
    private(set) var document: DraftDocument
    private let repository: any WritingRepository
    private let didSave: () -> Void
    private var subscriptions = Set<AnyCancellable>()

    init(document: DraftDocument, repository: any WritingRepository, didSave: @escaping () -> Void) {
        self.document = document; self.repository = repository; self.didSave = didSave
        title = document.task.title; prompt = document.task.prompt
        requirements = document.task.requirements.map(\.text).joined(separator: "\n")
        body = document.body; taskConfirmed = document.task.isConfirmed
        Publishers.CombineLatest4($title, $prompt, $requirements, $body)
            .dropFirst().debounce(for: .milliseconds(450), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.save() }.store(in: &subscriptions)
    }

    var part: WritingPart { document.task.part }
    var wordCount: Int { WordCounter.count(body) }
    var canConfirm: Bool { !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    @discardableResult func save() -> Bool {
        let points = requirements.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let taskChanged = document.task.title != title || document.task.prompt != prompt || document.task.requirements.map(\.text) != points
        if taskChanged {
            document.task.revision += 1; document.task.confirmedAt = nil; taskConfirmed = false
        }
        document.task.title = title; document.task.prompt = prompt
        document.task.requirements = points.enumerated().map { .init(id: "p\($0.offset + 1)", text: $0.element) }
        document.body = body; document.updatedAt = .now
        do { try repository.save(document); taskConfirmed = document.task.isConfirmed; saveError = nil; didSave(); return true }
        catch { saveError = "未能保存。请保留当前页面并重试。"; return false }
    }

    func confirmTask() {
        guard canConfirm, save() else { return }
        document.task.confirmedAt = .now
        do { try repository.save(document); taskConfirmed = true; didSave() }
        catch { saveError = "未能确认题目，请重试。" }
    }

    func finishEditing() {
        guard save() else { return }
        if document.isEmpty {
            do { try repository.deleteDraft(id: document.id); didSave() }
            catch { saveError = "未能关闭空白草稿，请重试。" }
        }
    }
}
