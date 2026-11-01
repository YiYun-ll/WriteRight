import Combine
import Foundation

@MainActor final class AppModel: ObservableObject {
    @Published private(set) var drafts: [DraftDocument] = []
    @Published private(set) var submissions: [SubmissionDocument] = []
    @Published private(set) var gradingJobs: [GradingJobDocument] = []
    @Published private(set) var gradingConnectionIssues: [UUID: String] = [:]
    @Published private(set) var gradingReports: [GradingReportDocument] = []
    @Published private(set) var notebook: [NotebookEntry] = []
    @Published private(set) var favorites: [FavoriteDocument] = []
    @Published private(set) var syncState = "未同步"
    /// Bumps after each successful merge of the account's cat, so the desk reloads what came back.
    @Published private(set) var companionRevision = 0
    @Published private(set) var account: AccountSession?
    @Published private(set) var nickname: String?
    @Published private(set) var isNicknameLoading = false
    @Published private(set) var isNicknameSaving = false
    @Published var nicknameError: String?
    private var nicknameTask: Task<Void, Never>?
    private var nicknameRevision = UUID()
    @Published private(set) var guestDraftCount = 0
    @Published private(set) var isReady = false
    @Published private(set) var isAuthBusy = false
    @Published private(set) var photoUploadPhase = "preparing"
    @Published var errorMessage: String?
    @Published var authErrorMessage: String?
    private(set) var repository: (any WritingRepository)?
    private let authService: (any AuthService)?
    private let gradingService: (any GradingService)?
    private let syncTransport: (any SyncTransport)?
    private let storeRoot: URL?
    private var hasRestoredSession = false
    private var isSigningOut = false

    init(repository: (any WritingRepository)? = nil, authService: (any AuthService)? = nil, storeRoot: URL? = nil, gradingService: (any GradingService)? = nil, syncTransport: (any SyncTransport)? = nil) {
        self.storeRoot = storeRoot
        self.syncTransport = syncTransport
        if let authService {
            self.authService = authService
        } else if repository == nil {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-test-store") && !ProcessInfo.processInfo.arguments.contains("-ui-test-live") {
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
        if let gradingService {
            self.gradingService = gradingService
        } else if let service = self.authService as? SupabaseAuthService {
            self.gradingService = SupabaseGradingService(client: service.client)
        } else {
            #if DEBUG
            if self.authService is UITestAuthService {
                self.gradingService = UITestGradingService()
            } else {
                self.gradingService = nil
            }
            #else
            self.gradingService = nil
            #endif
        }
        if let repository { self.repository = repository; refresh(); isReady = true }
        else { openStore() }
    }

    var canAuthenticate: Bool { authService != nil }
    var canGrade: Bool { account != nil && gradingService != nil }

    func observeAuth() async {
        guard !hasRestoredSession else { return }
        hasRestoredSession = true
        do { activate(try await authService?.currentSession()) }
        catch { authErrorMessage = "未能恢复登录，请稍后重试。" }
        await refreshActiveGradingJobs()
        guard let authService else { return }
        for await session in authService.sessionChanges {
            if session == nil, account != nil, !isSigningOut {
                authErrorMessage = "登录已失效，请重新登录。"
            }
            activate(session)
            await refreshActiveGradingJobs()
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
            authErrorMessage = AuthFailureMessage.message(for: error, operation: .sendCode)
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
            let session = try await authService.verifyCode(email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), code: code)
            activate(session)
            authErrorMessage = nil
            return true
        } catch {
            authErrorMessage = AuthFailureMessage.message(for: error, operation: .verifyCode)
            return false
        }
    }

    private var nicknameCache: ProfileNicknameCache {
        var namespace = storeRoot?.standardizedFileURL.path ?? "default"
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-ui-test-store"), args.indices.contains(index + 1) { namespace += args[index + 1] }
        #endif
        return ProfileNicknameCache(namespace: namespace)
    }
    func refreshNickname() async {
        guard let owner = account?.userID, let authService else { return }
        let revision = nicknameRevision
        isNicknameLoading = true
        defer { if nicknameRevision == revision { isNicknameLoading = false } }
        do {
            let value = try await authService.profileNickname(userID: owner)
            guard !Task.isCancelled, account?.userID == owner, nicknameRevision == revision else { return }
            nickname = ProfileNicknameCache.normalized(value); nicknameCache.save(nickname, userID: owner); nicknameError = nil
        } catch {
            if !Task.isCancelled && account?.userID == owner && nicknameRevision == revision { nicknameError = "昵称暂时未能读取，已保留本机记录。" }
        }
    }
    func saveNickname(_ value: String) async -> Bool {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count <= 20, !clean.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 || CharacterSet.newlines.contains($0) || (0x202A...0x202E).contains($0.value) || (0x2066...0x2069).contains($0.value) }) else {
            nicknameError = "昵称最多20个字，请不要使用换行或控制字符。"; return false
        }
        guard let owner = account?.userID, let authService, !isNicknameSaving else { return false }
        nicknameTask?.cancel(); nicknameRevision = UUID(); let revision = nicknameRevision
        isNicknameLoading = false; isNicknameSaving = true; nicknameError = nil
        defer { if nicknameRevision == revision { isNicknameSaving = false } }
        do {
            let saved = try await authService.updateNickname(clean, userID: owner)
            guard account?.userID == owner && nicknameRevision == revision else { return false }
            nickname = ProfileNicknameCache.normalized(saved); nicknameCache.save(nickname, userID: owner)
            return true
        } catch {
            if account?.userID == owner && nicknameRevision == revision { nicknameError = "昵称未能保存，请检查网络后重试。原昵称还在。" }
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
            let root = try storeRoot ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let guestImages = ScanImageStore(root: root.appendingPathComponent("JuGuang/local/images"))
            let accountImages = try scanImageStore()
            for document in documents where !existingIDs.contains(document.id) {
                // Photo drafts point at images by file name; copy them before the draft can resolve against the account folder.
                let pages = (document.pages ?? []) + (document.task.sourcePages ?? [])
                for path in pages.flatMap({ [$0.relativePath] + ($0.uploadRelativePath.map { [$0] } ?? []) }) {
                    guard let source = guestImages.url(path), let target = accountImages.url(path),
                          FileManager.default.fileExists(atPath: source.path), !FileManager.default.fileExists(atPath: target.path) else { continue }
                    _ = try accountImages.save(data: Data(contentsOf: source), id: UUID(uuidString: String(path.dropLast(4)))!)
                }
                try repository?.save(document)
            }
            for document in documents { try guest.deleteDraft(id: document.id) }
            try reload()
            refreshGuestDraftCount()
        } catch { errorMessage = "迁入未完成。本机原稿已保留，请重试。" }
    }

    func openStore() {
        repository = nil; drafts = []; submissions = []; gradingJobs = []; gradingReports = []; gradingConnectionIssues = [:]
        notebook = []; favorites = []; isReady = false
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
        for task in pollingTasks.values { task.cancel() }
        pollingTasks.removeAll()
        nicknameTask?.cancel(); nicknameRevision = UUID()
        nickname = session.flatMap { nicknameCache.load($0.userID) }
        isNicknameLoading = false; isNicknameSaving = false; nicknameError = nil
        syncState = "未同步"
        account = session
        openStore()
        if session != nil { nicknameTask = Task { [weak self] in await self?.refreshNickname() } }
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
        gradingJobs = try repository.gradingJobs(); gradingReports = try repository.gradingReports()
        drafts = try repository.drafts(); submissions = try repository.submissions()
        favorites = try repository.favorites()
        notebook = try repository.notebookChanges().map(\.entry).filter { $0.deletedAt == nil }
    }

    func submitGrading(_ draft: DraftDocument) async -> GradingJobDocument? {
        guard let gradingService, let repository, canGrade else {
            authErrorMessage = "请先登录后再提交批改。"
            return nil
        }
        guard !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "请先输入正文。"
            return nil
        }
        guard draft.transcriptionConfirmed else {
            errorMessage = "请先完成转录核对。"
            return nil
        }
        guard !OCRTranscript.containsUnresolved(draft.body) else {
            errorMessage = "请先替换待确认的识别文字。"
            return nil
        }
        let ownerID = account?.userID
        let fingerprint = ContentFingerprint.hash(draft.body)
        if let previous = submissions.first(where: { $0.draftID == draft.id && $0.contentHash == fingerprint && $0.task == draft.task }),
           let job = gradingJobs.first(where: { $0.submissionID == previous.id }) {
            if job.status != .completed { await retryGrading(job) }
            return gradingJobs.first { $0.id == job.id }
        }
        let submission = SubmissionDocument(
            id: UUID(), draftID: draft.id, task: draft.task, originalText: draft.body,
            wordCount: draft.wordCount, contentHash: fingerprint,
            sentences: SentenceSegmenter.sentences(in: draft.body), submittedAt: .now
        )
        let key = UUID()
        let durableJob = GradingJobDocument(id: key, submissionID: submission.id, idemKey: key,
            status: .queued, stage: .evaluate, errorCode: nil, updatedAt: .now)
        do {
            try repository.saveSubmission(submission)
            try repository.saveGradingJob(durableJob)
            try reload()
            let response = try await gradingService.submit(
                task: draft.task, submissionID: submission.id,
                originalText: draft.body, idemKey: durableJob.idemKey
            )
            guard account?.userID == ownerID else { return nil }
            guard response.jobId == durableJob.id else { throw GradingServiceError.invalidResponse }
            try apply(response, submissionID: submission.id)
            startPolling(durableJob.id)
            return gradingJobs.first { $0.id == durableJob.id }
        } catch {
            guard account?.userID == ownerID else { return nil }
            var failed = durableJob; failed.status = .failed; failed.errorCode = "SUBMIT_UNCONFIRMED"
            try? repository.saveGradingJob(failed)
            errorMessage = "提交未确认，原稿和任务已保留。请在练习页的批改任务中重试。"
            try? reload()
            return nil
        }
    }

    func refreshActiveGradingJobs() async {
        for job in gradingJobs where job.status == .queued || job.status == .running {
            await refreshGrading(job)
            startPolling(job.id)
        }
    }

    func refreshGrading(_ job: GradingJobDocument) async {
        guard let gradingService, canGrade else { return }
        let ownerID = account?.userID
        do {
            let response = try await gradingService.status(jobID: job.id)
            guard account?.userID == ownerID else { return }
            guard response.jobId == job.id else { throw GradingServiceError.invalidResponse }
            try apply(response, submissionID: job.submissionID)
            gradingConnectionIssues.removeValue(forKey: job.id)
            if response.status == .queued || response.status == .running { startPolling(job.id) }
        } catch {
            if account?.userID == ownerID {
                gradingConnectionIssues[job.id] = "暂时无法更新进度，任务已保留。"
            }
        }
    }

    func retryGrading(_ job: GradingJobDocument) async {
        guard let gradingService, canGrade, let submission = submissions.first(where: { $0.id == job.submissionID }) else { return }
        let ownerID = account?.userID
        do {
            let response: GradingStatusResponse
            if let pages = submission.essayPages, !pages.isEmpty {
                let store = try scanImageStore()
                func bytes(_ pages: [ScanPageDocument]) throws -> [Data] {
                    try pages.map { page in
                        guard let path = page.uploadRelativePath, let url = store.url(path) else { throw ScanError.invalidImage }
                        return try Data(contentsOf: url)
                    }
                }
                response = try await gradingService.submitPhotos(taskID: submission.task.id, part: submission.task.part, submissionID: submission.id, idemKey: job.idemKey, taskImages: bytes(submission.task.sourcePages ?? []), essayImages: bytes(pages))
            } else {
                response = try await gradingService.submit(task: submission.task, submissionID: submission.id, originalText: submission.originalText, idemKey: job.idemKey)
            }
            guard account?.userID == ownerID else { return }
            guard response.jobId == job.id else { throw GradingServiceError.invalidResponse }
            try apply(response, submissionID: submission.id)
            startPolling(job.id)
        } catch {
            #if DEBUG
            if let failure = error as? GradingServiceError {
                switch failure {
                case .http(let status, let code): print("Grading request failed: \(status) \(code)")
                case .invalidResponse: print("Grading response validation failed")
                }
            } else { print("Grading request failure type: \(type(of: error))") }
            #endif
            if account?.userID == ownerID { errorMessage = "重试失败，原稿和任务已保留。" }
        }
    }

    private func apply(_ response: GradingStatusResponse, submissionID: UUID) throws {
        guard let repository else { throw LocalStoreError.unavailable }
        let previous = gradingJobs.first { $0.id == response.jobId }
        let job = GradingJobDocument(
            id: response.jobId, submissionID: submissionID, idemKey: previous?.idemKey ?? response.jobId,
            status: response.status, stage: response.stage, errorCode: response.errorCode, updatedAt: .now
        )
        guard response.status != .completed || response.report != nil else { throw GradingServiceError.invalidResponse }
        if let report = response.report {
            guard report.jobID == job.id, report.submissionID == submissionID,
                  let source = submissions.first(where: { $0.id == submissionID }) else { throw GradingServiceError.invalidResponse }
            let original = source.originalText as NSString
            guard report.part == source.task.part, report.report.score.max == source.task.part.maximumScore,
                  report.sentences.allSatisfy({ $0.startUTF16 >= 0 && $0.lengthUTF16 >= 0 && $0.startUTF16 + $0.lengthUTF16 <= original.length && original.substring(with: NSRange(location: $0.startUTF16, length: $0.lengthUTF16)) == $0.original }) else { throw GradingServiceError.invalidResponse }
            if let photo = report.report.photoReview {
                let identity = [source.task.part.rawValue] + photo.sources.map { "\($0.role):\($0.page):\($0.checksum)" }
                guard source.originalText.isEmpty, report.sentences.isEmpty,
                      report.report.corrections.isEmpty,
                      ContentFingerprint.hash(identity.joined(separator: "\n")) == source.contentHash else { throw GradingServiceError.invalidResponse }
            }
            try repository.saveGradingReport(report)
        }
        try repository.saveGradingJob(job)
        try reload()
    }

    private var pollingTasks: [UUID: Task<Void, Never>] = [:]
    private func startPolling(_ jobID: UUID) {
        guard pollingTasks[jobID] == nil else { return }
        let ownerID = account?.userID
        pollingTasks[jobID] = Task { [weak self] in
            defer { self?.pollingTasks[jobID] = nil }
            // Quick checks for the first two minutes, then gentler ones for long queues (about 40 minutes in total).
            for attempt in 0..<300 {
                guard let self, self.account?.userID == ownerID,
                      let job = self.gradingJobs.first(where: { $0.id == jobID }) else { return }
                if job.status == .completed || job.status == .failed { return }
                do { try await Task.sleep(for: .seconds(attempt < 60 ? 2 : 10)) } catch { return }
                await self.refreshGrading(job)
            }
        }
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

    func transcribeImage(_ image: Data) async throws -> ImageTranscriptionResponse {
        guard let gradingService, canGrade else { throw GradingServiceError.invalidResponse }
        let owner = account?.userID
        let upload = try await Task.detached(priority: .userInitiated) {
            try ImageUploadEncoder.jpeg(from: image)
        }.value
        try Task.checkCancellation()
        guard account?.userID == owner else { throw AuthServiceError.invalidSession }
        let result = try await gradingService.transcribeImage(upload)
        guard account?.userID == owner else { throw AuthServiceError.invalidSession }
        return result
    }

    func submitPhotoGrading(_ draft: DraftDocument) async -> GradingJobDocument? {
        guard let gradingService, let repository, canGrade, let originals = draft.pages, !originals.isEmpty else { return nil }
        let owner = account?.userID
        if let previous = submissions.last(where: { $0.draftID == draft.id && $0.essayPages?.map(\.id) == originals.map(\.id) && $0.task.sourcePages?.map(\.id) == draft.task.sourcePages?.map(\.id) && $0.task.part == draft.task.part }), let job = gradingJobs.first(where: { $0.submissionID == previous.id }) {
            if job.status == .failed { await retryGrading(job) }
            return gradingJobs.first { $0.id == job.id }
        }
        photoUploadPhase = "preparing"
        var durableJob: GradingJobDocument?
        var pendingUploads: [String] = []
        var preparedStore: ScanImageStore?
        var draftStored = false
        do {
            let store = try scanImageStore(); preparedStore = store
            func prepare(_ pages: [ScanPageDocument]) async throws -> ([ScanPageDocument], [Data]) {
                var prepared: [ScanPageDocument] = []; var data: [Data] = []
                for var page in pages {
                    try Task.checkCancellation()
                    guard let originalURL = store.url(page.relativePath) else { throw ScanError.invalidImage }
                    let source = try Data(contentsOf: originalURL)
                    let upload: Data
                    if let path = page.uploadRelativePath, let url = store.url(path) { upload = try Data(contentsOf: url) }
                    else {
                        upload = try await Task.detached(priority: .userInitiated) { try ImageUploadEncoder.jpeg(from: source) }.value
                        try Task.checkCancellation()
                        let path = try store.save(data: upload, id: UUID())
                        page.uploadRelativePath = path; pendingUploads.append(path)
                    }
                    prepared.append(page); data.append(upload)
                }
                return (prepared, data)
            }
            let topic = try await prepare(draft.task.sourcePages ?? [])
            let essay = try await prepare(originals)
            guard account?.userID == owner else { throw AuthServiceError.invalidSession }
            var saved = draft; saved.task.sourcePages = topic.0; saved.pages = essay.0
            let taskHashes = topic.1.map(ContentFingerprint.hash)
            let essayHashes = essay.1.map(ContentFingerprint.hash)
            saved.task.photoFingerprint = taskHashes.isEmpty ? nil : ContentFingerprint.hash(([draft.task.part.rawValue] + taskHashes).joined(separator: "\n"))
            let identity = [draft.task.part.rawValue] + taskHashes.enumerated().map { "task:\($0.offset + 1):\($0.element)" } + essayHashes.enumerated().map { "essay:\($0.offset + 1):\($0.element)" }
            let submission = SubmissionDocument(id: UUID(), draftID: saved.id, task: saved.task, originalText: "", wordCount: 0, contentHash: ContentFingerprint.hash(identity.joined(separator: "\n")), sentences: [], submittedAt: .now, essayPages: essay.0)
            let key = UUID()
            let job = GradingJobDocument(id: key, submissionID: submission.id, idemKey: key, status: .queued, stage: .evaluate, errorCode: nil, updatedAt: .now)
            try repository.save(saved); draftStored = true
            try repository.saveSubmission(submission); try repository.saveGradingJob(job)
            durableJob = job; try reload(); photoUploadPhase = "uploading"
            let response = try await gradingService.submitPhotos(taskID: saved.task.id, part: saved.task.part, submissionID: submission.id, idemKey: key, taskImages: topic.1, essayImages: essay.1)
            guard account?.userID == owner, response.jobId == key else { throw AuthServiceError.invalidSession }
            try apply(response, submissionID: submission.id); startPolling(key)
            return gradingJobs.first { $0.id == key }
        } catch {
            if !draftStored { for path in pendingUploads { try? preparedStore?.remove(path) } }
            guard account?.userID == owner else { return nil }
            if var job = durableJob {
                job.status = .failed; job.errorCode = "SUBMIT_UNCONFIRMED"
                try? repository.saveGradingJob(job); try? reload()
                return job
            }
            errorMessage = error is ImageUploadError ? "图片过大或未能读取，请裁去无关边缘后重试。原图仍在本机。" : "照片暂时未能提交，原稿已保留，请稍后重试。"
            return nil
        }
    }

    /// Cached copy first, then the photo this device uploaded, then the network; whatever is found
    /// is kept so the report still opens offline.
    func gradingPhoto(_ source: PhotoSource) async throws -> Data {
        guard let owner = account?.userID else { throw AuthServiceError.invalidSession }
        let cache = try? reportPhotoCache()
        if let cached = cache?.data(for: source) { return cached }
        if let local = uploadedOriginal(for: source) { try? cache?.store(local, for: source); return local }
        guard let gradingService, canGrade else { throw AuthServiceError.invalidSession }
        let data = try await gradingService.photoData(source)
        guard account?.userID == owner else { throw AuthServiceError.invalidSession }
        try? cache?.store(data, for: source)
        return data
    }

    private func reportPhotoCache() throws -> ReportPhotoCache {
        guard let account else { throw AuthServiceError.invalidSession }
        let root = try storeRoot ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return ReportPhotoCache(root: root.appendingPathComponent("JuGuang/accounts/\(account.userID.uuidString)/report-photos"))
    }

    /// The exact bytes sent for grading are still on this device when the photos were taken here.
    private func uploadedOriginal(for source: PhotoSource) -> Data? {
        guard let store = try? scanImageStore(), source.page >= 1 else { return nil }
        for submission in submissions {
            let pages = (source.role == "task" ? submission.task.sourcePages : submission.essayPages) ?? []
            guard pages.indices.contains(source.page - 1), let path = pages[source.page - 1].uploadRelativePath,
                  let url = store.url(path), let data = try? Data(contentsOf: url),
                  ContentFingerprint.hash(data) == source.checksum.lowercased() else { continue }
            return data
        }
        return nil
    }

    func analyzePhotos(part: WritingPart, taskImages: [Data], essayImages: [Data]) async throws -> PhotoAnalysisResponse {
        guard let gradingService, canGrade else { throw AuthServiceError.invalidSession }
        let owner = account?.userID
        let uploads = try await Task.detached(priority: .userInitiated) {
            try (taskImages.map { try ImageUploadEncoder.jpeg(from: $0) }, essayImages.map { try ImageUploadEncoder.jpeg(from: $0) })
        }.value
        try Task.checkCancellation()
        guard account?.userID == owner else { throw AuthServiceError.invalidSession }
        let response = try await gradingService.analyzePhotos(part: part, taskImages: uploads.0, essayImages: uploads.1)
        try Task.checkCancellation()
        guard account?.userID == owner else { throw AuthServiceError.invalidSession }
        return response
    }

    func scanImageStore() throws -> ScanImageStore {
        let root = try storeRoot ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let scope = account.map { "accounts/\($0.userID.uuidString)" } ?? "local"
        return ScanImageStore(root: root.appendingPathComponent("JuGuang/\(scope)/images"))
    }

    func backupScanPages(_ pages: [ScanPageDocument]) async -> Bool {
        guard UserDefaults.standard.bool(forKey: "imageBackupEnabled") else { return true }
        guard let userID = account?.userID, let service = authService as? SupabaseAuthService else {
            errorMessage = "登录后才会备份扫描原图。"
            return false
        }
        do {
            guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
                  let apiKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
                  let base = URL(string: rawURL), !apiKey.isEmpty else { return false }
            let store = try scanImageStore()
            let session = try await service.client.auth.session
            for page in pages {
                guard let path = ScanImageBackupPath.objectPath(userID: userID, pageID: page.id),
                      let fileURL = store.url(page.relativePath),
                      let data = try? Data(contentsOf: fileURL) else { continue }
                var request = URLRequest(url: storageObjectURL(base: base, path: path))
                request.httpMethod = "POST"
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue(apiKey, forHTTPHeaderField: "apikey")
                request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                request.setValue("true", forHTTPHeaderField: "x-upsert")
                request.httpBody = data
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw ScanError.backupFailed
                }
            }
            return true
        } catch {
            return false
        }
    }

    private func storageObjectURL(base: URL, path: String) -> URL {
        path.split(separator: "/").reduce(base.appendingPathComponent("storage/v1/object/essay-images")) { url, part in
            url.appendingPathComponent(String(part))
        }
    }

    func parseTask(part: WritingPart, text: String, images: [Data]) async throws -> ParsedTaskResponse {
        guard let gradingService, canGrade else { throw AuthServiceError.invalidSession }
        let owner = account?.userID
        let uploads = try await Task.detached(priority: .userInitiated) {
            try images.map { try ImageUploadEncoder.jpeg(from: $0) }
        }.value
        try Task.checkCancellation()
        guard account?.userID == owner else { throw AuthServiceError.invalidSession }
        let result = try await gradingService.parseTask(part: part, text: text, images: uploads)
        guard account?.userID == owner else { throw AuthServiceError.invalidSession }
        return result
    }

    private var syncTask: (owner: UUID, task: Task<Void, Never>)?
    /// Pull-to-refresh and the sync button can fire together; a second call joins the running sync
    /// instead of pushing the same base revision twice and manufacturing conflict copies.
    func syncNow() async {
        guard let userID = account?.userID, let repository else {
            syncState = "登录后同步"
            return
        }
        if let running = syncTask, running.owner == userID { await running.task.value; return }
        let transport = currentSyncTransport
        syncState = "正在同步"
        let task = Task { [weak self] in
            do {
                let summary = try await AccountSynchronizer.sync(userID: userID, repository: repository, transport: transport)
                guard let self, self.account?.userID == userID else { return }
                try self.reload()
                await self.syncCompanion()
                self.syncState = summary.conflicts > 0 ? "有冲突副本" : "已同步"
            } catch {
                guard let self, self.account?.userID == userID else { return }
                self.syncState = "同步失败"
                self.errorMessage = "同步未完成。本机内容已保留，请重试。"
            }
        }
        syncTask = (userID, task)
        await task.value
        if syncTask?.owner == userID { syncTask = nil }
    }

    private var currentSyncTransport: any SyncTransport {
        syncTransport ?? SupabaseSyncTransport(accessToken: { [authService] in
            guard let service = authService as? SupabaseAuthService else { throw SyncTransportError.unavailable }
            return try await service.client.auth.session.accessToken
        })
    }
    private var companionTask: (owner: UUID, task: Task<Void, Never>)?
    var companionStore = CompanionStore()
    /// The cat is small and merge-only, so it syncs quietly when the desk opens. A failure keeps
    /// local growth and retries next time; it never blocks writing data or shows an error.
    func syncCompanion() async {
        guard let userID = account?.userID else { return }
        if let running = companionTask, running.owner == userID { await running.task.value; return }
        let transport = currentSyncTransport
        let task = Task { [weak self] in
            guard let store = self?.companionStore,
                  (try? await CompanionSync.sync(userID: userID, store: store, transport: transport)) != nil,
                  let self, self.account?.userID == userID else { return }
            // Even with nothing new, the desk reloads so its upload flag clears.
            self.companionRevision += 1
        }
        companionTask = (userID, task)
        await task.value
        if companionTask?.owner == userID { companionTask = nil }
    }

    @discardableResult func saveNotebook(_ entry: NotebookEntry) -> Bool {
        guard let repository else { return false }
        do { var saved = entry; saved.updatedAt = .now; try repository.saveNotebook(saved); try reload(); return true }
        catch { errorMessage = "这条记录暂时没能收好，请保留输入后重试。"; return false }
    }

    @discardableResult func restoreNotebook(_ entry: NotebookEntry) -> Bool {
        var restored = entry
        if let previous = try? repository?.notebookChanges().first(where: { $0.entry.id == entry.id }), previous.entry.deletedAt != nil {
            // Restore under a new ID even while deletion is in flight, so its late acknowledgement cannot erase the undo.
            restored.id = UUID()
        }
        restored.deletedAt = nil
        return saveNotebook(restored)
    }

    func isKept(expression: String) -> Bool {
        let normalized = FavoriteDocument.normalize(expression)
        return !normalized.isEmpty && favorites.contains { $0.deletedAt == nil && $0.normalized == normalized }
    }

    func keep(expression: ReviewExpression, report: GradingReportDocument) {
        guard let repository else { return }
        let sentence = report.sentences.first { $0.id == report.report.corrections.first?.sentenceID }?.original
            ?? report.sentences.first?.original ?? ""
        let incoming = FavoriteDocument.make(
            expression: expression.expression, meaning: expression.meaning, usage: expression.usage,
            reportID: report.id, sentence: sentence
        )
        do { try repository.keepFavorite(incoming); try reload() }
        catch { errorMessage = "未能收藏，请重试。" }
    }

    func deleteFavorite(id: UUID) {
        do { try repository?.deleteFavorite(id: id); try reload() }
        catch { errorMessage = "未能取消收藏，请重试。" }
    }

    func deleteAccount() async {
        guard account != nil, let authService else { return }
        let removed = account
        // Deleting signs out; that session change is expected, not an expired login.
        isSigningOut = true
        defer { isSigningOut = false }
        do {
            try await authService.deleteAccount()
        } catch {
            errorMessage = "账号删除未完成。本机数据仍在，请重试。"
            return
        }
        // Close the account's store before removing its files.
        activate(nil)
        syncState = "未同步"
        guard let removed else { return }
        companionStore.erase(owner: removed.userID.uuidString); LegacyDeskNote.erase(owner: removed.userID.uuidString)
        nicknameCache.erase(removed.userID)
        do { try removeAccountFiles(removed) }
        catch { errorMessage = "账号已删除，但这台设备上的部分本机文件未能清理。可以稍后删除 App 来彻底清除。" }
    }

    private func removeAccountFiles(_ account: AccountSession) throws {
        let root = try storeRoot ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let folder = root.appendingPathComponent("JuGuang/accounts/\(account.userID.uuidString)")
        if FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.removeItem(at: folder)
        }
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

    func note(_ message: String) { saveError = message }

    func useEssayScan(_ pages: [ScanPageDocument], append: Bool) {
        let text = pages.map(\.correctedText).joined(separator: "\n\n")
        body = append && !body.isEmpty ? body + "\n\n" + text : text
        document.pages = append ? (document.pages ?? []) + pages : pages
        document.source = pages.allSatisfy { $0.transcriptionSource == "ai_photo" } ? "ai_photo" : "ocr"
        document.transcriptionConfirmed = pages.allSatisfy(\.confirmed)
        save()
    }

    func useTaskScan(_ pages: [ScanPageDocument], directions: String, parsed: ParsedTaskDocument?) {
        prompt = directions
        if let parsed { requirements = parsed.requiredPoints.map(\.description).joined(separator: "\n") }
        guard save() else { return }
        document.task.sourcePages = pages
        if let parsed {
            document.task.chartFacts = parsed.chartFacts.map { var fact = $0; fact.confirmedByUser = true; return fact }
            document.task.uncertainFields = []
            document.task.confirmedAt = .now
            taskConfirmed = true
        } else {
            document.task.chartFacts = nil
            document.task.uncertainFields = nil
            document.task.confirmedAt = nil
            taskConfirmed = false
        }
        save()
    }

    func finishEditing() {
        guard save() else { return }
        if document.isEmpty {
            do { try repository.deleteDraft(id: document.id); didSave() }
            catch { saveError = "未能关闭空白草稿，请重试。" }
        }
    }
}
