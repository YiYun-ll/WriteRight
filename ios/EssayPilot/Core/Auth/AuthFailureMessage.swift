import Foundation
import Supabase

/// Only show known categories and numeric codes, never server bodies or credentials.
enum AuthFailureMessage {
    enum Operation { case sendCode, verifyCode }

    static func message(for error: Error, operation: Operation) -> String {
        let network = error as NSError
        if network.domain == NSURLErrorDomain {
            let detail: String
            switch URLError.Code(rawValue: network.code) {
            case .notConnectedToInternet, .dataNotAllowed:
                detail = "当前无法联网，请检查 WriteRight 的无线数据权限，或切换 Wi-Fi 后重试。"
            case .timedOut:
                detail = "连接登录服务超时，请切换 Wi-Fi 或其他网络后重试。"
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
                detail = "与登录服务的安全连接失败，请切换网络后重试。"
            default:
                detail = "当前网络无法连接登录服务，请切换 Wi-Fi 或其他网络后重试。"
            }
            return detail + "（连接错误 \(network.code)）"
        }
        if case let AuthError.api(_, code, _, response) = error {
            switch code {
            case .overEmailSendRateLimit, .overRequestRateLimit:
                return "验证码请求过于频繁，请稍等一会儿再试。（AUTH-RATE）"
            case .emailAddressNotAuthorized:
                return "发信服务暂不允许向此地址发送邮件，请联系维护者检查邮件配置。（AUTH-MAIL）"
            case .signupDisabled, .emailProviderDisabled, .otpDisabled:
                return "邮箱登录暂不可用，请联系维护者检查登录配置。（AUTH-CONFIG）"
            case .otpExpired, .invalidCredentials:
                if operation == .verifyCode { return "验证码无效或已过期，请重新获取后再试。（AUTH-CODE）" }
            default: break
            }
            switch response.statusCode {
            case 429: return "验证码请求过于频繁，请稍等一会儿再试。（AUTH-RATE）"
            case 500...599: return "登录服务暂时未能完成请求，请稍后重试；若持续失败，请联系维护者。（服务错误 \(response.statusCode)）"
            case 401, 403: return "登录连接配置未通过验证，请联系维护者检查此安装包。（AUTH-CONFIG）"
            default: return "登录服务未能接受请求，请核对邮箱后重试。（服务错误 \(response.statusCode)）"
            }
        }
        return operation == .verifyCode
            ? "验证码未能验证，请确认验证码后重试。（AUTH-UNKNOWN）"
            : "验证码未能发送，请稍后重试；若持续失败，请联系维护者。（AUTH-UNKNOWN）"
    }
}
