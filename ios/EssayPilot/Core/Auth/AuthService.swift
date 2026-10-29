import Foundation
import Supabase

struct AccountSession: Equatable, Sendable {
    let userID: UUID
    let email: String
}

protocol AuthService: Sendable {
    var sessionChanges: AsyncStream<AccountSession?> { get }
    func currentSession() async throws -> AccountSession?
    func requestCode(email: String) async throws
    func verifyCode(email: String, code: String) async throws -> AccountSession
    func updateEmail(_ email: String) async throws
    func signOut() async throws
}

enum AuthServiceError: Error {
    case invalidSession
    case invalidTestCode
}

struct SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    init?(bundle: Bundle = .main) {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              let url = URL(string: rawURL), url.host != nil, !key.isEmpty else { return nil }
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: .init(auth: .init(
                storage: KeychainLocalStorage(service: "com.yiyun.essaypilot.auth"),
                storageKey: "account-session-v1",
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

    func signOut() async throws {
        try await client.auth.signOut()
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
    nonisolated var sessionChanges: AsyncStream<AccountSession?> { AsyncStream { _ in } }

    func currentSession() async throws -> AccountSession? { session }
    func requestCode(email: String) async throws {}
    func verifyCode(email: String, code: String) async throws -> AccountSession {
        guard code == "123456" else { throw AuthServiceError.invalidTestCode }
        let session = AccountSession(
            userID: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
            email: email
        )
        self.session = session
        return session
    }
    func updateEmail(_ email: String) async throws {
        guard let session else { throw AuthServiceError.invalidSession }
        self.session = AccountSession(userID: session.userID, email: email)
    }
    func signOut() async throws { session = nil }
}
#endif
