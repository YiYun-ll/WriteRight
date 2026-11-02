import Foundation
import SwiftData

@Model final class LocalWritingTask {
    @Attribute(.unique) var id: UUID
    var ownerKey: String
    var payload: Data
    var updatedAt: Date
    var revision: Int
    var serverRevision: Int64
    var dirty: Bool
    var deletedAt: Date?

    init(document: WritingTaskDocument, ownerKey: String, payload: Data) {
        self.id = document.id; self.ownerKey = ownerKey; self.payload = payload
        updatedAt = .now; revision = document.revision; serverRevision = 0; dirty = true
    }
}

@Model final class LocalWritingDraft {
    @Attribute(.unique) var id: UUID
    var taskID: UUID
    var ownerKey: String
    var payload: Data
    var updatedAt: Date
    var serverRevision: Int64
    var dirty: Bool
    var deletedAt: Date?

    init(document: DraftDocument, ownerKey: String, payload: Data) {
        id = document.id; taskID = document.task.id; self.ownerKey = ownerKey
        self.payload = payload; updatedAt = document.updatedAt; serverRevision = 0; dirty = true
    }
}

@Model final class LocalWritingSubmission {
    @Attribute(.unique) var id: UUID
    var taskID: UUID
    var ownerKey: String
    var payload: Data
    var submittedAt: Date
    var serverRevision: Int64
    var dirty: Bool
    var deletedAt: Date?

    init(document: SubmissionDocument, ownerKey: String, payload: Data) {
        id = document.id; taskID = document.task.id; self.ownerKey = ownerKey
        self.payload = payload; submittedAt = document.submittedAt; serverRevision = 0; dirty = true
    }
}

@Model final class LocalGradingJob {
    @Attribute(.unique) var id: UUID
    var submissionID: UUID
    var ownerKey: String
    var payload: Data
    var updatedAt: Date

    init(document: GradingJobDocument, ownerKey: String, payload: Data) {
        id = document.id; submissionID = document.submissionID; self.ownerKey = ownerKey
        self.payload = payload; updatedAt = document.updatedAt
    }
}

@Model final class LocalGradingReport {
    @Attribute(.unique) var id: UUID
    var jobID: UUID
    var submissionID: UUID
    var ownerKey: String
    var payload: Data
    var createdAt: Date

    init(document: GradingReportDocument, ownerKey: String, payload: Data) {
        id = document.id; jobID = document.jobID; submissionID = document.submissionID
        self.ownerKey = ownerKey; self.payload = payload; createdAt = document.createdAt
    }
}

@Model final class LocalGradingReportSyncState {
    @Attribute(.unique) var reportID: UUID
    var ownerKey: String
    var serverRevision: Int64
    var dirty: Bool
    var deletedAt: Date?

    init(reportID: UUID, ownerKey: String) {
        self.reportID = reportID; self.ownerKey = ownerKey
        serverRevision = 0; dirty = true
    }
}

enum WritingSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [LocalWritingTask.self, LocalWritingDraft.self, LocalWritingSubmission.self]
    }
}

enum WritingSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [LocalWritingTask.self, LocalWritingDraft.self, LocalWritingSubmission.self, LocalGradingJob.self, LocalGradingReport.self]
    }
}

@Model final class LocalFavorite {
    @Attribute(.unique) var id: UUID
    var ownerKey: String
    var payload: Data
    var serverRevision: Int64
    var dirty: Bool
    var deletedAt: Date?

    init(document: FavoriteDocument, ownerKey: String, payload: Data) {
        id = document.id
        self.ownerKey = ownerKey
        self.payload = payload
        serverRevision = 0
        dirty = true
        deletedAt = document.deletedAt
    }
}

@Model final class LocalSyncState {
    @Attribute(.unique) var ownerKey: String
    var cursor: Int64
    init(ownerKey: String, cursor: Int64 = 0) { self.ownerKey = ownerKey; self.cursor = cursor }
}

enum WritingSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        [LocalWritingTask.self, LocalWritingDraft.self, LocalWritingSubmission.self, LocalGradingJob.self, LocalGradingReport.self, LocalFavorite.self, LocalSyncState.self]
    }
}

@Model final class LocalNotebookEntry {
    @Attribute(.unique) var id: UUID
    var ownerKey: String
    var payload: Data
    var serverRevision: Int64
    var dirty: Bool
    init(id: UUID, ownerKey: String, payload: Data) {
        self.id = id; self.ownerKey = ownerKey; self.payload = payload
        serverRevision = 0; dirty = true
    }
}
@Model final class LocalNotebookCursor {
    @Attribute(.unique) var ownerKey: String
    var cursor: Int64
    init(ownerKey: String, cursor: Int64 = 0) { self.ownerKey = ownerKey; self.cursor = cursor }
}
enum WritingSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)
    static var models: [any PersistentModel.Type] { WritingSchemaV3.models + [LocalNotebookEntry.self, LocalNotebookCursor.self] }
}

enum WritingSchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)
    static var models: [any PersistentModel.Type] { WritingSchemaV4.models + [LocalGradingReportSyncState.self] }
}

enum WritingMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [WritingSchemaV1.self, WritingSchemaV2.self, WritingSchemaV3.self, WritingSchemaV4.self, WritingSchemaV5.self] }
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: WritingSchemaV1.self, toVersion: WritingSchemaV2.self),
            .lightweight(fromVersion: WritingSchemaV2.self, toVersion: WritingSchemaV3.self),
            .lightweight(fromVersion: WritingSchemaV3.self, toVersion: WritingSchemaV4.self),
            .lightweight(fromVersion: WritingSchemaV4.self, toVersion: WritingSchemaV5.self)
        ]
    }
}

enum LocalStoreError: LocalizedError {
    case ownerMismatch, immutableSubmission, immutableReport, unavailable
    var errorDescription: String? {
        switch self {
        case .ownerMismatch: return "这份练习不属于当前账号。"
        case .immutableSubmission: return "已提交的原文不能覆盖，请新建一稿。"
        case .immutableReport: return "评分报告不能覆盖。"
        case .unavailable: return "练习库暂时不可用，请重试。"
        }
    }
}

@MainActor final class SwiftDataWritingRepository: WritingRepository {
    let container: ModelContainer
    private let context: ModelContext
    private let ownerKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(ownerKey: String = "local", storeURL: URL? = nil, inMemory: Bool = false) throws {
        self.ownerKey = ownerKey
        let schema = Schema(WritingSchemaV5.models)
        let configuration: ModelConfiguration
        if let storeURL {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        }
        container = try ModelContainer(for: schema, migrationPlan: WritingMigrationPlan.self, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
        encoder.outputFormatting = [.sortedKeys]
    }

    func drafts() throws -> [DraftDocument] {
        let owner = ownerKey
        let descriptor = FetchDescriptor<LocalWritingDraft>(
            predicate: #Predicate { $0.ownerKey == owner && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\LocalWritingDraft.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { try decoder.decode(DraftDocument.self, from: $0.payload) }
    }

    func submissions() throws -> [SubmissionDocument] {
        let owner = ownerKey
        let descriptor = FetchDescriptor<LocalWritingSubmission>(
            predicate: #Predicate { $0.ownerKey == owner && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\LocalWritingSubmission.submittedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { try decoder.decode(SubmissionDocument.self, from: $0.payload) }
    }

    func save(_ draft: DraftDocument) throws {
        let draftID = draft.id
        let taskID = draft.task.id
        let draftData = try encoder.encode(draft)
        let taskData = try encoder.encode(draft.task)
        do {
            if let task = try context.fetch(FetchDescriptor<LocalWritingTask>(predicate: #Predicate { $0.id == taskID })).first {
                guard task.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
                task.payload = taskData; task.revision = draft.task.revision; task.updatedAt = .now; task.dirty = true
            } else {
                context.insert(LocalWritingTask(document: draft.task, ownerKey: ownerKey, payload: taskData))
            }
            if let stored = try context.fetch(FetchDescriptor<LocalWritingDraft>(predicate: #Predicate { $0.id == draftID })).first {
                guard stored.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
                stored.payload = draftData; stored.updatedAt = draft.updatedAt; stored.dirty = true; stored.deletedAt = nil
            } else {
                context.insert(LocalWritingDraft(document: draft, ownerKey: ownerKey, payload: draftData))
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    func saveSubmission(_ submission: SubmissionDocument) throws {
        let id = submission.id
        if let existing = try context.fetch(FetchDescriptor<LocalWritingSubmission>(predicate: #Predicate { $0.id == id })).first {
            guard existing.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
            let stored = try decoder.decode(SubmissionDocument.self, from: existing.payload)
            guard stored == submission else { throw LocalStoreError.immutableSubmission }
            return
        }
        context.insert(LocalWritingSubmission(document: submission, ownerKey: ownerKey, payload: try encoder.encode(submission)))
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func deleteDraft(id: UUID) throws {
        guard let stored = try context.fetch(FetchDescriptor<LocalWritingDraft>(predicate: #Predicate { $0.id == id })).first else { return }
        guard stored.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
        stored.deletedAt = .now; stored.dirty = true
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func gradingJobs() throws -> [GradingJobDocument] {
        let owner = ownerKey
        let descriptor = FetchDescriptor<LocalGradingJob>(
            predicate: #Predicate { $0.ownerKey == owner },
            sortBy: [SortDescriptor(\LocalGradingJob.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { try decoder.decode(GradingJobDocument.self, from: $0.payload) }
    }

    func gradingReports() throws -> [GradingReportDocument] {
        let owner = ownerKey
        let descriptor = FetchDescriptor<LocalGradingReport>(
            predicate: #Predicate { $0.ownerKey == owner },
            sortBy: [SortDescriptor(\LocalGradingReport.createdAt, order: .reverse)]
        )
        let states = try context.fetch(FetchDescriptor<LocalGradingReportSyncState>(predicate: #Predicate { $0.ownerKey == owner }))
        let deleted = Set(states.filter { $0.deletedAt != nil }.map(\.reportID))
        return try context.fetch(descriptor).filter { !deleted.contains($0.id) }.map { try decoder.decode(GradingReportDocument.self, from: $0.payload) }
    }

    func saveGradingJob(_ job: GradingJobDocument) throws {
        let id = job.id
        do {
            if let stored = try context.fetch(FetchDescriptor<LocalGradingJob>(predicate: #Predicate { $0.id == id })).first {
                guard stored.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
                stored.payload = try encoder.encode(job); stored.updatedAt = job.updatedAt
            } else {
                context.insert(LocalGradingJob(document: job, ownerKey: ownerKey, payload: try encoder.encode(job)))
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    func saveGradingReport(_ report: GradingReportDocument) throws {
        let id = report.id
        if let stored = try context.fetch(FetchDescriptor<LocalGradingReport>(predicate: #Predicate { $0.id == id })).first {
            guard stored.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
            let existing = try decoder.decode(GradingReportDocument.self, from: stored.payload)
            guard existing == report else { throw LocalStoreError.immutableReport }
            return
        }
        context.insert(LocalGradingReport(document: report, ownerKey: ownerKey, payload: try encoder.encode(report)))
        do { try context.save() } catch { context.rollback(); throw error }
    }

    private func gradingReportState(id: UUID) throws -> LocalGradingReportSyncState {
        if let state = try context.fetch(FetchDescriptor<LocalGradingReportSyncState>(predicate: #Predicate { $0.reportID == id })).first {
            guard state.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
            return state
        }
        let state = LocalGradingReportSyncState(reportID: id, ownerKey: ownerKey)
        context.insert(state)
        return state
    }

    func deleteGradingReport(id: UUID) throws {
        guard let stored = try context.fetch(FetchDescriptor<LocalGradingReport>(predicate: #Predicate { $0.id == id })).first else { return }
        guard stored.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
        let state = try gradingReportState(id: id)
        state.deletedAt = .now; state.dirty = true
        try commit()
    }

    func gradingReportChanges() throws -> [GradingReportChange] {
        let owner = ownerKey
        let states = try context.fetch(FetchDescriptor<LocalGradingReportSyncState>(predicate: #Predicate { $0.ownerKey == owner }))
        let statesByID = Dictionary(uniqueKeysWithValues: states.map { ($0.reportID, $0) })
        return try context.fetch(FetchDescriptor<LocalGradingReport>(predicate: #Predicate { $0.ownerKey == owner })).map { row in
            let state = statesByID[row.id]
            return GradingReportChange(report: try decoder.decode(GradingReportDocument.self, from: row.payload), baseRevision: state?.serverRevision ?? 0, deleted: state?.deletedAt != nil, dirty: state?.dirty ?? true)
        }
    }

    func acknowledgeGradingReport(id: UUID, revision: Int64, deleted: Bool) throws {
        guard let row = try context.fetch(FetchDescriptor<LocalGradingReport>(predicate: #Predicate { $0.id == id })).first else { return }
        guard row.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
        let state = try gradingReportState(id: id)
        state.serverRevision = revision; state.dirty = false
        if deleted { state.deletedAt = state.deletedAt ?? .now }
        try commit()
    }

    func applyRemoteGradingReport(_ report: GradingReportDocument, revision: Int64) throws {
        let id = report.id
        if let row = try context.fetch(FetchDescriptor<LocalGradingReport>(predicate: #Predicate { $0.id == id })).first {
            guard row.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
            let state = try gradingReportState(id: id)
            state.serverRevision = revision
            if !state.dirty {
                row.payload = try encoder.encode(report); state.deletedAt = nil
            }
        } else {
            context.insert(LocalGradingReport(document: report, ownerKey: ownerKey, payload: try encoder.encode(report)))
            let state = LocalGradingReportSyncState(reportID: id, ownerKey: ownerKey)
            state.serverRevision = revision; state.dirty = false
            context.insert(state)
        }
        try commit()
    }

    func draftChanges() throws -> [DraftChange] {
        let owner = ownerKey
        return try context.fetch(FetchDescriptor<LocalWritingDraft>(predicate: #Predicate { $0.ownerKey == owner })).map { row in
            DraftChange(draft: try decoder.decode(DraftDocument.self, from: row.payload), baseRevision: row.serverRevision, deleted: row.deletedAt != nil, dirty: row.dirty)
        }
    }

    func acknowledgeDraft(id: UUID, revision: Int64, deleted: Bool, pushed: DraftDocument?) throws {
        guard let row = try context.fetch(FetchDescriptor<LocalWritingDraft>(predicate: #Predicate { $0.id == id })).first else { return }
        guard row.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
        row.serverRevision = revision
        if try pushed.map({ try encoder.encode($0) == row.payload }) ?? true { row.dirty = false }
        if deleted { row.deletedAt = row.deletedAt ?? .now }
        try commit()
    }

    func applyRemoteDraft(_ draft: DraftDocument, revision: Int64) throws {
        let data = try encoder.encode(draft)
        let taskData = try encoder.encode(draft.task)
        let draftID = draft.id
        let taskID = draft.task.id
        if let task = try context.fetch(FetchDescriptor<LocalWritingTask>(predicate: #Predicate { $0.id == taskID })).first {
            guard task.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
            task.payload = taskData
            task.revision = draft.task.revision
            task.updatedAt = draft.updatedAt
            task.dirty = false
        } else {
            let inserted = LocalWritingTask(document: draft.task, ownerKey: ownerKey, payload: taskData)
            inserted.dirty = false
            context.insert(inserted)
        }
        if let row = try context.fetch(FetchDescriptor<LocalWritingDraft>(predicate: #Predicate { $0.id == draftID })).first {
            guard row.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
            row.payload = data
            row.updatedAt = draft.updatedAt
            row.serverRevision = revision
            row.dirty = false
            row.deletedAt = nil
        } else {
            let inserted = LocalWritingDraft(document: draft, ownerKey: ownerKey, payload: data)
            inserted.serverRevision = revision
            inserted.dirty = false
            inserted.deletedAt = nil
            context.insert(inserted)
        }
        try commit()
    }

    func syncCursor() throws -> Int64 {
        let owner = ownerKey
        return try context.fetch(FetchDescriptor<LocalSyncState>(predicate: #Predicate { $0.ownerKey == owner })).first?.cursor ?? 0
    }

    func setSyncCursor(_ cursor: Int64) throws {
        let owner = ownerKey
        if let state = try context.fetch(FetchDescriptor<LocalSyncState>(predicate: #Predicate { $0.ownerKey == owner })).first {
            state.cursor = cursor
        } else {
            context.insert(LocalSyncState(ownerKey: ownerKey, cursor: cursor))
        }
        try commit()
    }

    func favoriteChanges() throws -> [FavoriteChange] {
        let owner = ownerKey
        return try context.fetch(FetchDescriptor<LocalFavorite>(predicate: #Predicate { $0.ownerKey == owner })).map { row in
            FavoriteChange(favorite: try decoder.decode(FavoriteDocument.self, from: row.payload), baseRevision: row.serverRevision, deleted: row.deletedAt != nil, dirty: row.dirty)
        }
    }

    func acknowledgeFavorite(id: UUID, revision: Int64, deleted: Bool, pushed: FavoriteDocument?) throws {
        guard let row = try context.fetch(FetchDescriptor<LocalFavorite>(predicate: #Predicate { $0.id == id })).first else { return }
        guard row.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
        row.serverRevision = revision
        if try pushed.map({ try encoder.encode($0) == row.payload }) ?? true { row.dirty = false }
        if deleted { row.deletedAt = row.deletedAt ?? .now }
        try commit()
    }

    func applyRemoteFavorite(_ favorite: FavoriteDocument, revision: Int64) throws {
        let data = try encoder.encode(favorite)
        let favoriteID = favorite.id
        if let row = try context.fetch(FetchDescriptor<LocalFavorite>(predicate: #Predicate { $0.id == favoriteID })).first {
            guard row.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
            row.payload = data
            row.serverRevision = revision
            row.dirty = false
            row.deletedAt = favorite.deletedAt
        } else {
            let inserted = LocalFavorite(document: favorite, ownerKey: ownerKey, payload: data)
            inserted.serverRevision = revision
            inserted.dirty = false
            context.insert(inserted)
        }
        try commit()
    }

    func keepFavorite(_ favorite: FavoriteDocument) throws {
        let normalized = favorite.normalized
        let owner = ownerKey
        let rows = try context.fetch(FetchDescriptor<LocalFavorite>(predicate: #Predicate { $0.ownerKey == owner }))
        let matches = rows.filter { (try? decoder.decode(FavoriteDocument.self, from: $0.payload).normalized) == normalized }
        // A tombstone the server already knows cannot be revived; keeping again starts a new favorite.
        if let row = matches.first(where: { $0.deletedAt == nil }) ?? matches.first(where: { $0.serverRevision == 0 }),
           let source = favorite.sources.first {
            guard row.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
            let existing = try decoder.decode(FavoriteDocument.self, from: row.payload)
            var merged = existing.merging(meaning: favorite.meaning, usage: favorite.usage, source: source)
            merged.id = existing.id; merged.deletedAt = nil
            row.payload = try encoder.encode(merged)
            row.deletedAt = nil
            row.dirty = true
        } else {
            context.insert(LocalFavorite(document: favorite, ownerKey: ownerKey, payload: try encoder.encode(favorite)))
        }
        try commit()
    }

    func deleteFavorite(id: UUID) throws {
        guard let row = try context.fetch(FetchDescriptor<LocalFavorite>(predicate: #Predicate { $0.id == id })).first else { return }
        guard row.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
        row.deletedAt = .now
        row.dirty = true
        if var favorite = try? decoder.decode(FavoriteDocument.self, from: row.payload) {
            favorite.deletedAt = row.deletedAt
            row.payload = try encoder.encode(favorite)
        }
        try commit()
    }

    func favorites() throws -> [FavoriteDocument] {
        try favoriteChanges().filter { !$0.deleted }.map(\.favorite)
    }

    func notebookChanges() throws -> [NotebookChange] {
        let owner = ownerKey
        return try context.fetch(FetchDescriptor<LocalNotebookEntry>(predicate: #Predicate { $0.ownerKey == owner })).map {
            NotebookChange(entry: try decoder.decode(NotebookEntry.self, from: $0.payload), revision: $0.serverRevision, dirty: $0.dirty)
        }
    }
    func saveNotebook(_ entry: NotebookEntry) throws {
        let id = entry.id
        do {
            if let row = try context.fetch(FetchDescriptor<LocalNotebookEntry>(predicate: #Predicate { $0.id == id })).first {
                guard row.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
                row.payload = try encoder.encode(entry); row.dirty = true
            } else { context.insert(LocalNotebookEntry(id: id, ownerKey: ownerKey, payload: try encoder.encode(entry))) }
            try context.save()
        } catch { context.rollback(); throw error }
    }
    func acknowledgeNotebook(_ entry: NotebookEntry, revision: Int64, deleted: Bool) throws {
        let id = entry.id
        guard let row = try context.fetch(FetchDescriptor<LocalNotebookEntry>(predicate: #Predicate { $0.id == id })).first else { return }
        guard row.ownerKey == ownerKey else { throw LocalStoreError.ownerMismatch }
        let unchanged = row.payload == (try encoder.encode(entry))
        row.serverRevision = revision
        if unchanged { row.dirty = false }
        if deleted {
            var stored = try decoder.decode(NotebookEntry.self, from: row.payload)
            stored.deletedAt = stored.deletedAt ?? .now
            row.payload = try encoder.encode(stored); row.dirty = false
        }
        try commit()
    }
    func applyNotebook(_ entry: NotebookEntry, revision: Int64) throws {
        try saveNotebook(entry)
        try acknowledgeNotebook(entry, revision: revision, deleted: entry.deletedAt != nil)
    }
    func notebookCursor() throws -> Int64 {
        let owner = ownerKey
        return try context.fetch(FetchDescriptor<LocalNotebookCursor>(predicate: #Predicate { $0.ownerKey == owner })).first?.cursor ?? 0
    }
    func setNotebookCursor(_ cursor: Int64) throws {
        let owner = ownerKey
        if let row = try context.fetch(FetchDescriptor<LocalNotebookCursor>(predicate: #Predicate { $0.ownerKey == owner })).first { row.cursor = cursor }
        else { context.insert(LocalNotebookCursor(ownerKey: owner, cursor: cursor)) }
        try commit()
    }

    /// The shared context has autosave off; a failed save must not leave its changes pending for the next save.
    private func commit() throws {
        do { try context.save() } catch { context.rollback(); throw error }
    }

    func exportData() throws -> Data {
        let backup = try WritingBackup(schemaVersion: 3, exportedAt: .now, drafts: drafts(), submissions: submissions(), reports: gradingReports(), favorites: favorites(), notebook: notebookChanges().map(\.entry).filter { $0.deletedAt == nil })
        return try encoder.encode(backup)
    }
}
