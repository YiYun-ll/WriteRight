import Foundation

struct SyncOperation: Equatable, Sendable {
    var entityType: String
    var entityID: UUID
    var operation: String
    var baseRevision: Int64
    var payload: Data
}

struct SyncChange: Equatable, Sendable {
    var entityType: String
    var entityID: UUID
    var operation: String
    var revision: Int64
    var serverRevision: Int64
    var payload: Data
}

enum SyncPushResult: Equatable, Sendable {
    case applied(revision: Int64, serverRevision: Int64)
    case conflict(SyncChange)
    case deleted(serverRevision: Int64)
}

protocol SyncTransport {
    func push(userID: UUID, op: SyncOperation) async throws -> SyncPushResult
    func pull(userID: UUID, after: Int64) async throws -> [SyncChange]
    /// Merges this device's cat into the account's copy and returns the combined growth.
    func mergeCompanion(userID: UUID, growth: CompanionGrowth) async throws -> CompanionGrowth
}

enum SyncCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
    static func decoder() -> JSONDecoder { JSONDecoder() }
}

final class SyncDirectory: SyncTransport {
    private struct Head {
        var userID: UUID
        var entityType: String
        var entityID: UUID
        var revision: Int64
        var deleted: Bool
        var payload: Data
        var serverRevision: Int64
    }

    private var heads: [String: Head] = [:]
    private var log: [Head] = []
    private var nextRevision: Int64 = 1
    private var companions: [UUID: CompanionGrowth] = [:]

    func push(userID: UUID, op: SyncOperation) async throws -> SyncPushResult { push(userID, op) }
    func pull(userID: UUID, after: Int64) async throws -> [SyncChange] { pull(userID, after) }
    func mergeCompanion(userID: UUID, growth: CompanionGrowth) async throws -> CompanionGrowth {
        let merged = companions[userID].map { $0.merged(with: growth) } ?? growth
        companions[userID] = merged
        return merged
    }

    func push(_ userID: UUID, _ op: SyncOperation) -> SyncPushResult {
        let key = Self.key(userID, op.entityType, op.entityID)
        let current = heads[key]
        if op.operation == "delete" {
            guard let current, !current.deleted else { return .deleted(serverRevision: current?.serverRevision ?? 0) }
            guard current.revision == op.baseRevision else { return .conflict(change(current)) }
            return write(userID, op, deleted: true, revision: current.revision + 1, payload: current.payload)
        }
        if let current, current.deleted { return .deleted(serverRevision: current.serverRevision) }
        if let current, current.payload == op.payload { return .applied(revision: current.revision, serverRevision: current.serverRevision) }
        if op.entityType == "report" || op.entityType == "submission", let current {
            return .applied(revision: current.revision, serverRevision: current.serverRevision)
        }
        let base = current?.revision ?? 0
        guard base == op.baseRevision else { return .conflict(change(current!)) }
        return write(userID, op, deleted: false, revision: base + 1, payload: op.payload)
    }

    func pull(_ userID: UUID, _ after: Int64) -> [SyncChange] {
        log.filter { $0.userID == userID && $0.serverRevision > after }.map(change)
    }

    private func write(_ userID: UUID, _ op: SyncOperation, deleted: Bool, revision: Int64, payload: Data) -> SyncPushResult {
        let serverRevision = nextRevision
        nextRevision += 1
        let head = Head(
            userID: userID, entityType: op.entityType, entityID: op.entityID, revision: revision,
            deleted: deleted, payload: payload, serverRevision: serverRevision
        )
        heads[Self.key(userID, op.entityType, op.entityID)] = head
        log.append(head)
        return deleted ? .deleted(serverRevision: serverRevision) : .applied(revision: revision, serverRevision: serverRevision)
    }

    private func change(_ head: Head) -> SyncChange {
        SyncChange(
            entityType: head.entityType, entityID: head.entityID, operation: head.deleted ? "delete" : "upsert",
            revision: head.revision, serverRevision: head.serverRevision, payload: head.payload
        )
    }

    private static func key(_ userID: UUID, _ type: String, _ id: UUID) -> String {
        "\(userID.uuidString.lowercased())|\(type)|\(id.uuidString.lowercased())"
    }
}

struct SyncSummary: Equatable {
    var conflicts: Int
    var applied: Int
}

@MainActor enum AccountSynchronizer {
    static func sync(
        userID: UUID, repository: any WritingRepository, transport: any SyncTransport,
        newID: @escaping () -> UUID = { UUID() }
    ) async throws -> SyncSummary {
        var conflicts = 0
        var applied = 0
        let encoder = SyncCoding.encoder()
        let decoder = SyncCoding.decoder()
        for change in try repository.draftChanges() where change.dirty {
            let result = try await transport.push(userID: userID, op: SyncOperation(
                entityType: "draft", entityID: change.draft.id, operation: change.deleted ? "delete" : "upsert",
                baseRevision: change.baseRevision, payload: try encoder.encode(change.draft)
            ))
            let outcome = try await resolveDraft(change, result: result, repository: repository, transport: transport, userID: userID, decoder: decoder, encoder: encoder, newID: newID)
            conflicts += outcome.conflicts
            applied += outcome.applied
        }
        for change in try repository.favoriteChanges() where change.dirty {
            let result = try await transport.push(userID: userID, op: SyncOperation(
                entityType: "favorite", entityID: change.favorite.id, operation: change.deleted ? "delete" : "upsert",
                baseRevision: change.baseRevision, payload: try encoder.encode(change.favorite)
            ))
            switch result {
            case .applied(let revision, _):
                try repository.acknowledgeFavorite(id: change.favorite.id, revision: revision, deleted: change.deleted, pushed: change.deleted ? nil : change.favorite)
                applied += 1
            case .deleted:
                try repository.acknowledgeFavorite(id: change.favorite.id, revision: change.baseRevision, deleted: true)
                applied += 1
            case .conflict(let server):
                if let remote = try? decoder.decode(FavoriteDocument.self, from: server.payload) {
                    try repository.applyRemoteFavorite(remote, revision: server.revision)
                }
                applied += 1
            }
        }
        for submission in try repository.submissions() {
            let result = try await transport.push(userID: userID, op: SyncOperation(
                entityType: "submission", entityID: submission.id, operation: "upsert", baseRevision: 0,
                payload: try encoder.encode(submission)
            ))
            if case .applied = result { applied += 1 }
        }
        for report in try repository.gradingReports() {
            let result = try await transport.push(userID: userID, op: SyncOperation(
                entityType: "report", entityID: report.id, operation: "upsert", baseRevision: 0,
                payload: try encoder.encode(report)
            ))
            if case .applied = result { applied += 1 }
        }
        var cursor = try repository.syncCursor()
        for item in try await transport.pull(userID: userID, after: cursor) {
            cursor = max(cursor, item.serverRevision)
            switch item.entityType {
            case "draft":
                if item.operation == "delete" {
                    if let local = try repository.draftChanges().first(where: { $0.draft.id == item.entityID }), local.dirty, !local.deleted,
                       local.draft.body != (try? decoder.decode(DraftDocument.self, from: item.payload))?.body {
                        try await fork(local.draft, repository: repository, newID: newID(), encoder: encoder, transport: transport, userID: userID)
                        conflicts += 1
                    }
                    try repository.acknowledgeDraft(id: item.entityID, revision: item.revision, deleted: true)
                } else if try repository.draftChanges().contains(where: { $0.draft.id == item.entityID && $0.dirty }) {
                    continue
                } else if let draft = try? decoder.decode(DraftDocument.self, from: item.payload) {
                    try repository.applyRemoteDraft(draft, revision: item.revision)
                    applied += 1
                }
            case "favorite":
                if item.operation == "delete" {
                    try repository.acknowledgeFavorite(id: item.entityID, revision: item.revision, deleted: true)
                } else if let favorite = try? decoder.decode(FavoriteDocument.self, from: item.payload) {
                    try repository.applyRemoteFavorite(favorite, revision: item.revision)
                    applied += 1
                }
            case "submission":
                if let submission = try? decoder.decode(SubmissionDocument.self, from: item.payload) {
                    try? repository.saveSubmission(submission)
                    applied += 1
                }
            case "report":
                if let report = try? decoder.decode(GradingReportDocument.self, from: item.payload) {
                    try? repository.saveGradingReport(report)
                    applied += 1
                }
            default:
                break
            }
        }
        try repository.setSyncCursor(cursor)
        // Separate cursor: an older client may have advanced the general stream past records.
        for change in try repository.notebookChanges() where change.dirty {
            let entry = change.entry
            let result = try await transport.push(userID: userID, op: SyncOperation(entityType: "record", entityID: entry.id, operation: entry.deletedAt == nil ? "upsert" : "delete", baseRevision: change.revision, payload: try encoder.encode(entry)))
            switch result {
            case .applied(let revision, _): try repository.acknowledgeNotebook(entry, revision: revision, deleted: entry.deletedAt != nil)
            case .deleted: try repository.acknowledgeNotebook(entry, revision: change.revision, deleted: true)
            case .conflict(let server):
                let remote = try? decoder.decode(NotebookEntry.self, from: server.payload)
                // A retried push whose first response was lost comes back as a conflict carrying our own content.
                if let remote, remote == (try? decoder.decode(NotebookEntry.self, from: encoder.encode(entry))) {
                    try repository.acknowledgeNotebook(entry, revision: server.revision, deleted: entry.deletedAt != nil)
                    continue
                }
                // Keep an edited copy instead of silently discarding someone's note.
                if entry.deletedAt == nil {
                    var copy = entry; copy.id = newID(); copy.title += "（另一份记录）"
                    try repository.saveNotebook(copy)
                    let pushed = try await transport.push(userID: userID, op: SyncOperation(entityType: "record", entityID: copy.id, operation: "upsert", baseRevision: 0, payload: try encoder.encode(copy)))
                    if case .applied(let revision, _) = pushed { try repository.acknowledgeNotebook(copy, revision: revision, deleted: false) }
                }
                if let remote { try repository.applyNotebook(remote, revision: server.revision) }
                conflicts += 1
            }
        }
        var notebookCursor = try repository.notebookCursor()
        while true {
            let page = try await transport.pull(userID: userID, after: notebookCursor)
            for item in page {
                notebookCursor = max(notebookCursor, item.serverRevision)
                guard item.entityType == "record", var entry = try? decoder.decode(NotebookEntry.self, from: item.payload) else { continue }
                let local = try repository.notebookChanges().first { $0.entry.id == item.entityID }
                if item.operation == "delete" { entry.deletedAt = entry.deletedAt ?? .now }
                else if local?.dirty == true { continue }
                else if let local, local.revision > item.revision { continue }
                try repository.applyNotebook(entry, revision: item.revision)
            }
            try repository.setNotebookCursor(notebookCursor)
            if page.count < 200 { break }
        }
        return SyncSummary(conflicts: conflicts, applied: applied)
    }

    private struct Outcome { var conflicts: Int; var applied: Int }

    private static func resolveDraft(
        _ change: DraftChange, result: SyncPushResult, repository: any WritingRepository, transport: any SyncTransport,
        userID: UUID, decoder: JSONDecoder, encoder: JSONEncoder, newID: () -> UUID
    ) async throws -> Outcome {
        switch result {
        case .applied(let revision, _):
            try repository.acknowledgeDraft(id: change.draft.id, revision: revision, deleted: change.deleted, pushed: change.deleted ? nil : change.draft)
            return Outcome(conflicts: 0, applied: 1)
        case .deleted:
            if !change.deleted, differsFromDeleted(change) {
                try await fork(change.draft, repository: repository, newID: newID(), encoder: encoder, transport: transport, userID: userID)
                try repository.acknowledgeDraft(id: change.draft.id, revision: change.baseRevision, deleted: true)
                return Outcome(conflicts: 1, applied: 1)
            }
            try repository.acknowledgeDraft(id: change.draft.id, revision: change.baseRevision, deleted: true)
            return Outcome(conflicts: 0, applied: 1)
        case .conflict(let server):
            if let remote = try? decoder.decode(DraftDocument.self, from: server.payload) {
                try repository.applyRemoteDraft(remote, revision: server.revision)
            }
            if change.draft.body != (try? decoder.decode(DraftDocument.self, from: server.payload))?.body {
                try await fork(change.draft, repository: repository, newID: newID(), encoder: encoder, transport: transport, userID: userID)
                return Outcome(conflicts: 1, applied: 1)
            }
            return Outcome(conflicts: 0, applied: 1)
        }
    }

    private static func differsFromDeleted(_ change: DraftChange) -> Bool { !change.draft.body.isEmpty }

    private static func fork(
        _ draft: DraftDocument, repository: any WritingRepository, newID: UUID, encoder: JSONEncoder,
        transport: any SyncTransport, userID: UUID
    ) async throws {
        var copy = draft
        copy.id = newID
        copy.conflictOf = draft.id
        copy.updatedAt = .now
        try repository.save(copy)
        let result = try await transport.push(userID: userID, op: SyncOperation(
            entityType: "draft", entityID: copy.id, operation: "upsert", baseRevision: 0, payload: try encoder.encode(copy)
        ))
        if case .applied(let revision, _) = result {
            try repository.acknowledgeDraft(id: copy.id, revision: revision, deleted: false)
        }
    }
}
