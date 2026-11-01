import Foundation

struct SupabaseSyncTransport: SyncTransport {
    var accessToken: @Sendable () async throws -> String

    func push(userID: UUID, op: SyncOperation) async throws -> SyncPushResult {
        struct Body: Encodable {
            struct Op: Encodable {
                let entityType: String
                let entityID: String
                let operation: String
                let baseRevision: Int64
                let payload: String
                enum CodingKeys: String, CodingKey {
                    case entityType = "entity_type"
                    case entityID = "entity_id"
                    case operation
                    case baseRevision = "base_revision"
                    case payload
                }
            }
            let op: Op
        }
        let body = Body(op: .init(
            entityType: op.entityType, entityID: op.entityID.uuidString.lowercased(), operation: op.operation,
            baseRevision: op.baseRevision, payload: String(decoding: op.payload, as: UTF8.self)
        ))
        let result = try await call("apply_sync_operation", body: body, as: RemotePush.self)
        if result.status == "applied" {
            return .applied(revision: result.revision ?? op.baseRevision, serverRevision: result.serverRevision ?? 0)
        }
        if result.status == "deleted" { return .deleted(serverRevision: result.serverRevision ?? 0) }
        let server = result.server
        return .conflict(SyncChange(
            entityType: op.entityType, entityID: op.entityID, operation: server?.operation ?? "upsert",
            revision: server?.revision ?? 0, serverRevision: server?.serverRevision ?? 0,
            payload: Data((server?.payload ?? "").utf8)
        ))
    }

    func pull(userID: UUID, after: Int64) async throws -> [SyncChange] {
        struct Body: Encodable { let afterRevision: Int64; enum CodingKeys: String, CodingKey { case afterRevision = "after_revision" } }
        let rows = try await call("sync_changes", body: Body(afterRevision: after), as: [RemoteChange].self)
        return rows.compactMap { row in
            guard let id = UUID(uuidString: row.entityID) else { return nil }
            return SyncChange(
                entityType: row.entityType, entityID: id, operation: row.operation, revision: row.revision,
                serverRevision: row.serverRevision, payload: Data(row.payload.utf8)
            )
        }
    }

    func mergeCompanion(userID: UUID, growth: CompanionGrowth) async throws -> CompanionGrowth {
        struct Body: Encodable { let incoming: CompanionGrowth }
        return try await call("merge_companion", body: Body(incoming: growth), as: CompanionGrowth.self)
    }

    private func call<Body: Encodable, Response: Decodable>(_ function: String, body: Body, as: Response.Type) async throws -> Response {
        let token = try await accessToken()
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let apiKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              let url = URL(string: rawURL)?.appendingPathComponent("rest/v1/rpc").appendingPathComponent(function) else {
            throw SyncTransportError.unavailable
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SyncTransportError.unavailable
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private struct RemotePush: Decodable {
    var status: String
    var revision: Int64?
    var serverRevision: Int64?
    var server: RemoteChange?
    enum CodingKeys: String, CodingKey {
        case status, revision, server
        case serverRevision = "server_revision"
    }
}

private struct RemoteChange: Decodable {
    var entityType: String
    var entityID: String
    var operation: String
    var revision: Int64
    var serverRevision: Int64
    var payload: String
    enum CodingKeys: String, CodingKey {
        case operation, revision, payload
        case entityType = "entity_type"
        case entityID = "entity_id"
        case serverRevision = "server_revision"
    }
}

enum SyncTransportError: Error { case unavailable }
