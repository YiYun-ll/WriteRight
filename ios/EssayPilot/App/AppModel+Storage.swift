import Foundation

@MainActor extension AppModel {
    var reportCacheLimitBytes: Int {
        let megabytes = UserDefaults.standard.integer(forKey: "reportPhotoCacheLimitMB")
        return (megabytes > 0 ? megabytes : 200) * 1_000_000
    }

    func reportCacheUsage() -> ReportPhotoCache.Usage {
        (try? reportPhotoCache().usage()) ?? ReportPhotoCache.Usage(bytes: 0, files: 0)
    }

    @discardableResult func trimReportPhotoCache() throws -> Int {
        try reportPhotoCache().trim(limitBytes: reportCacheLimitBytes)
    }

    @discardableResult func clearReportPhotoCache() throws -> Int {
        try reportPhotoCache().removeAll()
    }
}
