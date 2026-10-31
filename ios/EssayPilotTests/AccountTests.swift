import XCTest
@testable import EssayPilot

@MainActor final class AccountTests: XCTestCase {
    private var directory: URL!
    private var auth: TestAuthService!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        auth = TestAuthService()
    }

    override func tearDown() {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        directory = nil; auth = nil
    }

    func testGuestDraftMovesOnlyAfterExplicitMigration() async throws {
        let model = AppModel(authService: auth, storeRoot: directory)
        let draft = try XCTUnwrap(model.createDraft(part: .a))
        var edited = draft; edited.body = "Keep this private draft."
        try model.repository?.save(edited); model.refresh()

        let sent = await model.requestCode(email: "a@example.com")
        XCTAssertTrue(sent)
        let verified = await model.verifyCode(email: "a@example.com", code: "123456")
        XCTAssertTrue(verified)
        XCTAssertTrue(model.drafts.isEmpty)
        XCTAssertEqual(model.guestDraftCount, 1)

        model.migrateGuestDrafts()
        XCTAssertEqual(model.drafts.first?.body, edited.body)
        XCTAssertEqual(model.guestDraftCount, 0)

        await model.signOut()
        XCTAssertNil(model.account)
        XCTAssertTrue(model.drafts.isEmpty)
        let restored = await model.verifyCode(email: "a@example.com", code: "123456")
        XCTAssertTrue(restored)
        XCTAssertEqual(model.drafts.first?.id, edited.id)
    }

    func testSwitchingAccountsNeverExposesPreviousDrafts() async throws {
        let model = AppModel(authService: auth, storeRoot: directory)
        let signedIntoA = await model.verifyCode(email: "a@example.com", code: "123456")
        XCTAssertTrue(signedIntoA)
        let draft = try XCTUnwrap(model.createDraft(part: .b))
        var edited = draft; edited.body = "Account A only."
        try model.repository?.save(edited); model.refresh()

        await model.signOut()
        let signedIntoB = await model.verifyCode(email: "b@example.com", code: "123456")
        XCTAssertTrue(signedIntoB)
        XCTAssertTrue(model.drafts.isEmpty)

        await model.signOut()
        let restoredA = await model.verifyCode(email: "a@example.com", code: "123456")
        XCTAssertTrue(restoredA)
        XCTAssertEqual(model.drafts.first?.body, "Account A only.")
        XCTAssertNotEqual(model.account?.userID, auth.id(for: "b@example.com"))
    }

    func testInvalidCodeKeepsCurrentLocalWorkspace() async throws {
        let model = AppModel(authService: auth, storeRoot: directory)
        _ = model.createDraft(part: .a)
        let verified = await model.verifyCode(email: "a@example.com", code: "000000")
        XCTAssertFalse(verified)
        XCTAssertNil(model.account)
        XCTAssertEqual(model.drafts.count, 1)
        XCTAssertNotNil(model.authErrorMessage)
    }
}

private actor TestAuthService: AuthService {
    private var session: AccountSession?
    nonisolated var sessionChanges: AsyncStream<AccountSession?> { AsyncStream { _ in } }

    nonisolated func id(for email: String) -> UUID {
        UUID(uuidString: email == "a@example.com"
            ? "11111111-1111-4111-8111-111111111111"
            : "22222222-2222-4222-8222-222222222222")!
    }

    func currentSession() async throws -> AccountSession? { session }
    func requestCode(email: String) async throws {}
    func verifyCode(email: String, code: String) async throws -> AccountSession {
        guard code == "123456" else { throw AuthServiceError.invalidTestCode }
        let session = AccountSession(userID: id(for: email), email: email)
        self.session = session
        return session
    }
    func updateEmail(_ email: String) async throws {}
    func signOut() async throws { session = nil }
    func deleteAccount() async throws { session = nil }
}
