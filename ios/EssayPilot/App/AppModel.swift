import Combine
import Foundation

@MainActor final class AppModel: ObservableObject {
    @Published private(set) var drafts: [DraftDocument] = []
    @Published private(set) var submissions: [SubmissionDocument] = []
    @Published private(set) var account: AccountSession?
    @Published private(set) var guestDraftCount = 0
    @Published private(set) var isReady = false
    @Published private(set) var isAuthBusy = false
    @Published var errorMessage: String?
    @Published var authErrorMessage: String?
    private(set) var repository: (any WritingRepository)?
    private let authService: (any AuthService)?
    private let storeRoot: URL?
    private var hasRestoredSession = false
    private var isSigningOut = false

    init(repository: (any WritingRepository)? = nil, authService: (any AuthService)? = nil, storeRoot: URL? = nil) {
        self.storeRoot = storeRoot
        if let authService {
            self.authService = authService
        } else if repository == nil {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-test-store") {
                self.authService = UITestAuthService()
            } else {
                self.authService = SupabaseAuthService()
            }
            #else
            self.authService = SupabaseAuthService()
            #endif
        } else {
            self.authService = nil
        }
        if let repository { self.repository = repository; refresh(); isReady = true }
        else { openStore() }
    }

    var canAuthenticate: Bool { authService != nil }

    func observeAuth() async {
        guard !hasRestoredSession else { return }
        hasRestoredSession = true
        do { activate(try await authService?.currentSession()) }
        catch { authErrorMessage = "未能恢复登录，请稍后重试。" }
        guard let authService else { return }
        for await session in authService.sessionChanges {
            if session == nil, account != nil, !isSigningOut {
                authErrorMessage = "登录已失效，请重新登录。"
            }
            activate(session)
        }
    }

    func requestCode(email: String) async -> Bool {
        guard let authService, Self.validEmail(email) else {
            authErrorMessage = canAuthenticate ? "请输入有效的邮箱地址。" : "登录服务尚未配置。"
            return false
        }
        isAuthBusy = true
        defer { isAuthBusy = false }
        do {
            try await authService.requestCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            authErrorMessage = nil
            return true
        } catch {
            authErrorMessage = "验证码发送失败，请检查网络后重试。"
            return false
        }
    }

    func verifyCode(email: String, code: String) async -> Bool {
        guard let authService, code.count == 6, code.allSatisfy(\.isNumber) else {
            authErrorMessage = "请输入 6 位验证码。"
            return false
        }
        isAuthBusy = true
        defer { isAuthBusy = false }
        do {
            let session = try await authService.verifyCode(email: email, code: code)
            activate(session)
            authErrorMessage = nil
            return true
        } catch {
            authErrorMessage = "验证码无效或已过期，请重试。"
            return false
        }
    }

    func updateEmail(_ email: String) async -> Bool {
        guard let authService, Self.validEmail(email) else {
            authErrorMessage = "请输入有效的邮箱地址。"
            return false
        }
        isAuthBusy = true
        defer { isAuthBusy = false }
        do {
            try await authService.updateEmail(email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
            authErrorMessage = nil
            return true
        } catch {
            authErrorMessage = "邮箱变更失败，请重新登录后重试。"
            return false
        }
    }

    func signOut() async {
        guard let authService else { return }
        isAuthBusy = true; isSigningOut = true
        defer { isAuthBusy = false; isSigningOut = false }
        do {
            try await authService.signOut()
            activate(nil)
            authErrorMessage = nil
        } catch { authErrorMessage = "退出失败，请检查网络后重试。" }
    }

    func migrateGuestDrafts() {
        guard account != nil else { return }
        do {
            let guest = try makeRepository(account: nil)
            let documents = try guest.drafts()
            let existingIDs = Set(drafts.map(\.id))
            for document in documents where !existingIDs.contains(document.id) {
                try repository?.save(document)
            }
            for document in documents { try guest.deleteDraft(id: document.id) }
            try reload()
            refreshGuestDraftCount()
        } catch { errorMessage = "迁入未完成。本机原稿已保留，请重试。" }
    }

    func openStore() {
        repository = nil; drafts = []; submissions = []; isReady = false
        do {
            repository = try makeRepository(account: account)
            try reload(); isReady = true; errorMessage = nil
            refreshGuestDraftCount()
        } catch { isReady = false; errorMessage = "无法打开练习库。原有数据已保留，请重试。" }
    }

    func refresh() {
        do { try reload() } catch { errorMessage = "未能读取练习，请重试。" }
    }

    private func activate(_ session: AccountSession?) {
        guard account?.userID != session?.userID else { account = session; return }
        account = session
        openStore()
    }

    private func makeRepository(account: AccountSession?) throws -> any WritingRepository {
        let root = try storeRoot ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let ownerKey = account?.userID.uuidString ?? "local"
        var storePath = account.map { "JuGuang/accounts/\($0.userID.uuidString)/writing.store" } ?? "JuGuang/local/writing.store"
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-ui-test-store"), arguments.indices.contains(index + 1),
           let testID = UUID(uuidString: arguments[index + 1]) {
            let scope = account.map { "accounts/\($0.userID.uuidString)" } ?? "guest"
            storePath = "JuGuang/ui-tests/\(testID.uuidString)/\(scope)/writing.store"
        }
        #endif
        return try SwiftDataWritingRepository(ownerKey: ownerKey, storeURL: root.appendingPathComponent(storePath))
    }

    private func refreshGuestDraftCount() {
        do { guestDraftCount = account == nil ? drafts.count : try makeRepository(account: nil).drafts().count }
        catch { guestDraftCount = 0 }
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

    private static func validEmail(_ email: String) -> Bool {
        email.trimmingCharacters(in: .whitespacesAndNewlines).range(
            of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression
        ) != nil
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
