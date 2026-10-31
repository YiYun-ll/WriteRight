import XCTest
import Supabase
@testable import EssayPilot

final class AuthFailureTests: XCTestCase {
    private func failure(_ code: ErrorCode, status: Int) -> AuthError {
        .api(message: "Private server details user@example.com secret-token", errorCode: code,
             underlyingData: Data("private payload".utf8),
             underlyingResponse: HTTPURLResponse(url: URL(string: "https://example.invalid/auth")!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func testNetworkFailureIsNotPresentedAsInvalidCode() {
        let message = AuthFailureMessage.message(for: URLError(.secureConnectionFailed), operation: .verifyCode)
        XCTAssertTrue(message.contains("安全连接失败"))
        XCTAssertTrue(message.contains("-1200"))
        XCTAssertFalse(message.contains("验证码无效"))
        XCTAssertTrue(AuthFailureMessage.message(for: URLError(.notConnectedToInternet), operation: .sendCode).contains("无线数据权限"))
        XCTAssertTrue(AuthFailureMessage.message(for: URLError(.timedOut), operation: .sendCode).contains("超时"))
    }

    func testRateAndMailPolicyHaveActionableDifferentMessages() {
        XCTAssertTrue(AuthFailureMessage.message(for: failure(.overEmailSendRateLimit, status: 429), operation: .sendCode).contains("AUTH-RATE"))
        XCTAssertTrue(AuthFailureMessage.message(for: failure(.emailAddressNotAuthorized, status: 403), operation: .sendCode).contains("AUTH-MAIL"))
        XCTAssertTrue(AuthFailureMessage.message(for: failure(.signupDisabled, status: 422), operation: .sendCode).contains("AUTH-CONFIG"))
    }

    func testServerFailureDoesNotLeakBodyOrBlameNetwork() {
        let message = AuthFailureMessage.message(for: failure(.unexpectedFailure, status: 500), operation: .sendCode)
        XCTAssertTrue(message.contains("服务错误 500"))
        for secret in ["user@example.com", "secret-token", "private payload", "检查网络"] { XCTAssertFalse(message.contains(secret)) }
    }

    func testOnlyCodeRejectionUsesCodeMessage() {
        XCTAssertTrue(AuthFailureMessage.message(for: failure(.otpExpired, status: 403), operation: .verifyCode).contains("AUTH-CODE"))
        XCTAssertTrue(AuthFailureMessage.message(for: failure(.unknown, status: 401), operation: .sendCode).contains("AUTH-CONFIG"))
    }
}
