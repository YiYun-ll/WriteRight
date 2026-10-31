#if DEBUG
import Foundation
import Supabase

/// Explicit, read-only device diagnostics. Never runs in a distributed Release app.
@MainActor enum BackendConnectivityProbe {
    private static var hasRun = false
    private struct Result: Encodable {
        let endpoint: String
        let httpStatus: Int?
        let networkError: Int?
        var category: String? = nil
    }
    private struct Report: Encodable {
        let timestamp: Date
        let build: String
        let results: [Result]
    }

    static func runIfRequested() async {
        guard !hasRun, ProcessInfo.processInfo.arguments.contains("-debug-cloud-connectivity"),
              let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let backend = URL(string: raw), backend.scheme == "https",
              backend.host == "tdcxdiqvrfmppaqikgxu.supabase.co",
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String else { return }
        hasRun = true
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var results: [Result] = []
        for (label, url, authenticated) in [
            ("apple-control", URL(string: "https://www.apple.com/library/test/success.html")!, false),
            ("backend-health", backend.appendingPathComponent("functions/v1/health"), false),
            ("auth-settings", backend.appendingPathComponent("auth/v1/settings"), true)
        ] {
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            if authenticated { request.setValue(key, forHTTPHeaderField: "apikey") }
            do {
                let (_, response) = try await session.data(for: request)
                results.append(Result(endpoint: label, httpStatus: (response as? HTTPURLResponse)?.statusCode, networkError: nil))
            } catch {
                let error = error as NSError
                results.append(Result(endpoint: label, httpStatus: nil, networkError: error.domain == NSURLErrorDomain ? error.code : 0))
            }
        }
        // Explicit one-time diagnostic consent is supplied outside the app binary.
        if results.contains(where: { $0.endpoint == "auth-settings" && $0.httpStatus == 200 }),
           ProcessInfo.processInfo.arguments.contains("-debug-auth-send-once"),
           let email = ProcessInfo.processInfo.environment["WRITERIGHT_DIAGNOSTIC_EMAIL"],
           email.contains("@"), let auth = SupabaseAuthService() {
            do {
                try await auth.requestCode(email: email)
                results.append(Result(endpoint: "auth-send-once", httpStatus: 200, networkError: nil))
            } catch let error as AuthError {
                if case let .api(message, code, _, response) = error {
                    let allowedCodes: Set<String> = ["over_email_send_rate_limit", "over_request_rate_limit", "email_address_not_authorized", "signup_disabled", "unexpected_failure", "email_provider_disabled"]
                    let category = message.lowercased().contains("error sending") || message.lowercased().contains("smtp")
                        ? "mail_delivery_failure" : allowedCodes.contains(code.rawValue) ? code.rawValue : "auth_error"
                    results.append(Result(endpoint: "auth-send-once", httpStatus: response.statusCode, networkError: nil, category: category))
                } else {
                    results.append(Result(endpoint: "auth-send-once", httpStatus: nil, networkError: nil, category: "auth_error"))
                }
            } catch {
                let error = error as NSError
                results.append(Result(endpoint: "auth-send-once", httpStatus: nil, networkError: error.domain == NSURLErrorDomain ? error.code : 0))
            }
        }
        let report = Report(timestamp: .now, build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown", results: results)
        guard let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let data = try? JSONEncoder().encode(report) else { return }
        try? data.write(to: folder.appendingPathComponent("writeright-connectivity.json"), options: .atomic)
    }
}
#endif
