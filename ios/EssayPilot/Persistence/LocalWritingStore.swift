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

enum WritingSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [LocalWritingTask.self, LocalWritingDraft.self, LocalWritingSubmission.self]
    }
}

enum WritingMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [WritingSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum LocalStoreError: LocalizedError {
    case ownerMismatch, immutableSubmission, unavailable
    var errorDescription: String? {
        switch self {
        case .ownerMismatch: return "这份练习不属于当前账号。"
        case .immutableSubmission: return "已提交的原文不能覆盖，请新建一稿。"
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
        let schema = Schema(WritingSchemaV1.models)
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

    func exportData() throws -> Data {
        struct Backup: Encodable { let schemaVersion: Int; let exportedAt: Date; let drafts: [DraftDocument]; let submissions: [SubmissionDocument] }
        return try encoder.encode(Backup(schemaVersion: 1, exportedAt: .now, drafts: drafts(), submissions: submissions()))
    }
}
