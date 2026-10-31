import XCTest
@testable import EssayPilot

@MainActor final class NicknameTests: XCTestCase {
    func testNicknameSaveResetAndAccountIsolation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let auth = NicknameAuthStub(); let app = AppModel(authService: auth, storeRoot: root)
        _ = await app.verifyCode(email: "a@example.com", code: "123456")
        let saved = await app.saveNickname("  晨光  "); XCTAssertTrue(saved); XCTAssertEqual(app.nickname,"晨光")
        await app.signOut(); XCTAssertNil(app.nickname)
        _ = await app.verifyCode(email: "b@example.com", code: "123456"); await app.refreshNickname()
        XCTAssertNil(app.nickname)
        _ = await app.verifyCode(email: "a@example.com", code: "123456"); await app.refreshNickname()
        XCTAssertEqual(app.nickname,"晨光")
        let reset = await app.saveNickname("  "); XCTAssertTrue(reset); XCTAssertNil(app.nickname)
    }
    func testFailedSaveAndOfflineRestoreKeepVerifiedNickname() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let auth = NicknameAuthStub(); let app = AppModel(authService: auth, storeRoot: root)
        _ = await app.verifyCode(email: "a@example.com", code: "123456")
        _ = await app.saveNickname("保留的名字")
        await auth.failUpdates()
        let failed = await app.saveNickname("未保存的新名字")
        XCTAssertFalse(failed); XCTAssertEqual(app.nickname,"保留的名字")
        let invalid = await app.saveNickname(String(repeating:"字",count:21)); XCTAssertFalse(invalid)
        await auth.failReads()
        let reopened = AppModel(authService: auth, storeRoot: root)
        _ = await reopened.verifyCode(email: "a@example.com", code: "123456"); await reopened.refreshNickname()
        XCTAssertEqual(reopened.nickname,"保留的名字")
    }
    func testSlowProfileReadCannotOverwriteNewerSave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let auth = NicknameAuthStub(slow: true); let app = AppModel(authService: auth, storeRoot: root)
        _ = await app.verifyCode(email: "a@example.com", code: "123456")
        try await Task.sleep(for:.milliseconds(20))
        let saved = await app.saveNickname("新的称呼"); XCTAssertTrue(saved)
        try await Task.sleep(for:.milliseconds(150))
        XCTAssertEqual(app.nickname,"新的称呼")
    }
}
private actor NicknameAuthStub: AuthService {
    private var session: AccountSession?
    private var names: [UUID:String] = [:]
    private var badRead = false; private var badSave = false
    private let slow: Bool
    init(slow: Bool = false) { self.slow = slow }
    nonisolated var sessionChanges: AsyncStream<AccountSession?> { AsyncStream { _ in } }
    func currentSession() async throws -> AccountSession? { session }
    func requestCode(email: String) async throws {}
    func verifyCode(email: String, code: String) async throws -> AccountSession {
        let value = AccountSession(userID:UUID(uuidString:email.hasPrefix("a") ? "11111111-1111-4111-8111-111111111111" : "22222222-2222-4222-8222-222222222222")!,email:email)
        session = value; return value
    }
    func profileNickname(userID: UUID) async throws -> String? {
        let value = names[userID]
        if slow { try? await Task.sleep(for:.milliseconds(100)) }
        if badRead { throw AuthServiceError.invalidSession }
        return value
    }
    func updateNickname(_ nickname: String, userID: UUID) async throws -> String? {
        if badSave || session?.userID != userID { throw AuthServiceError.invalidSession }
        names[userID] = nickname; return ProfileNicknameCache.normalized(nickname)
    }
    func failReads() { badRead = true }; func failUpdates() { badSave = true }
    func updateEmail(_ email: String) async throws {}
    func signOut() async throws { session = nil }
    func deleteAccount() async throws { session = nil }
}
