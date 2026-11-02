import Foundation
import Supabase

struct AccountSession: Codable, Equatable, Sendable {
    let userID: UUID
    let email: String
}

protocol AuthService: Sendable {
    var sessionChanges: AsyncStream<AccountSession?> { get }
    func currentSession() async throws -> AccountSession?
    func requestCode(email: String) async throws
    func verifyCode(email: String, code: String) async throws -> AccountSession
    func updateEmail(_ email: String) async throws
    func profileNickname(userID: UUID) async throws -> String?
    func updateNickname(_ nickname: String, userID: UUID) async throws -> String?
    func signOut() async throws
    func deleteAccount() async throws
}

extension AuthService {
    func profileNickname(userID: UUID) async throws -> String? { nil }
    func updateNickname(_ nickname: String, userID: UUID) async throws -> String? { throw AuthServiceError.invalidSession }
}

enum AuthServiceError: Error {
    case invalidSession
    case invalidTestCode
}

/// Local simulator acceptance overrides are compiled out of release builds.
enum BackendConfiguration {
    static func value(_ key: String, bundle: Bundle) -> String? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-test-live"),
           let value = ProcessInfo.processInfo.environment["WRITERIGHT_" + key], !value.isEmpty {
            return value
        }
        #endif
        return bundle.object(forInfoDictionaryKey: key) as? String
    }
}

struct SupabaseAuthService: AuthService {
    let client: SupabaseClient

    init?(bundle: Bundle = .main) {
        guard let rawURL = BackendConfiguration.value("SUPABASE_URL", bundle: bundle),
              let key = BackendConfiguration.value("SUPABASE_PUBLISHABLE_KEY", bundle: bundle),
              let url = URL(string: rawURL), url.host != nil, !key.isEmpty else { return nil }
        var storageKey = "account-session-v1"
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-test-live"), let index = arguments.firstIndex(of: "-ui-test-store"), arguments.indices.contains(index + 1) {
            storageKey = "acceptance-" + arguments[index + 1]
        }
        #endif
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: .init(auth: .init(
                storage: KeychainLocalStorage(service: "com.yiyun.essaypilot.auth"),
                storageKey: storageKey,
                autoRefreshToken: true
            ))
        )
    }

    var sessionChanges: AsyncStream<AccountSession?> {
        AsyncStream { continuation in
            let task = Task {
                for await change in client.auth.authStateChanges {
                    continuation.yield(change.session.map(AccountSession.init))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func currentSession() async throws -> AccountSession? {
        do { return try AccountSession(session: await client.auth.session) }
        catch AuthError.sessionMissing { return nil }
    }

    func requestCode(email: String) async throws {
        try await client.auth.signInWithOTP(email: email, shouldCreateUser: true)
    }

    func verifyCode(email: String, code: String) async throws -> AccountSession {
        let response = try await client.auth.verifyOTP(email: email, token: code, type: .email)
        guard let session = response.session else { throw AuthServiceError.invalidSession }
        return AccountSession(session: session)
    }

    func updateEmail(_ email: String) async throws {
        _ = try await client.auth.update(user: UserAttributes(email: email))
    }

    private struct NicknameProfile: Decodable { let nickname: String? }
    private struct NicknameWrite: Encodable { let nickname: String }
    func profileNickname(userID: UUID) async throws -> String? {
        guard try await client.auth.session.user.id == userID else { throw AuthServiceError.invalidSession }
        let profile: NicknameProfile = try await client.from("profiles").select("nickname")
            .eq("id", value: userID.uuidString).single().execute().value
        return ProfileNicknameCache.normalized(profile.nickname)
    }
    func updateNickname(_ nickname: String, userID: UUID) async throws -> String? {
        guard try await client.auth.session.user.id == userID else { throw AuthServiceError.invalidSession }
        let profile: NicknameProfile = try await client.from("profiles").update(NicknameWrite(nickname: nickname))
            .eq("id", value: userID.uuidString).select("nickname").single().execute().value
        return ProfileNicknameCache.normalized(profile.nickname)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        let session = try await client.auth.session
        guard let rawURL = BackendConfiguration.value("SUPABASE_URL", bundle: .main),
              let apiKey = BackendConfiguration.value("SUPABASE_PUBLISHABLE_KEY", bundle: .main),
              let url = URL(string: rawURL)?.appendingPathComponent("functions/v1/delete-account") else {
            throw AuthServiceError.invalidSession
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthServiceError.invalidSession
        }
        // The account is already gone on the server; a failed remote logout must not report the deletion as unfinished.
        try? await client.auth.signOut()
    }
}

private extension AccountSession {
    init(session: Session) {
        self.init(userID: session.user.id, email: session.user.email ?? "")
    }
}

#if DEBUG
actor UITestAuthService: AuthService {
    private var session: AccountSession?
    private var nicknames: [UUID: String] = [:]
    nonisolated var sessionChanges: AsyncStream<AccountSession?> { AsyncStream { _ in } }

    func currentSession() async throws -> AccountSession? { session }
    func requestCode(email: String) async throws {
        if ProcessInfo.processInfo.arguments.contains("-ui-test-auth-network-failure") {
            throw URLError(.secureConnectionFailed)
        }
    }
    func verifyCode(email: String, code: String) async throws -> AccountSession {
        guard code == "123456" else { throw AuthServiceError.invalidTestCode }
        let session = AccountSession(
            userID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            email: email
        )
        self.session = session
        return session
    }
    func profileNickname(userID: UUID) async throws -> String? { ProfileNicknameCache.normalized(nicknames[userID]) }
    func updateNickname(_ nickname: String, userID: UUID) async throws -> String? {
        guard session?.userID == userID else { throw AuthServiceError.invalidSession }
        nicknames[userID] = nickname; return ProfileNicknameCache.normalized(nickname)
    }
    func updateEmail(_ email: String) async throws {
        guard let session else { throw AuthServiceError.invalidSession }
        self.session = AccountSession(userID: session.userID, email: email)
    }
    func signOut() async throws { session = nil }
    func deleteAccount() async throws { session = nil }
}
#endif
