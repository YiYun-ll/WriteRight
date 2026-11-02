import Foundation

struct WritingBackup: Codable {
    static let currentVersion = 4
    var schemaVersion: Int
    var exportedAt: Date
    var drafts: [DraftDocument]
    var submissions: [SubmissionDocument]
    var reports: [GradingReportDocument]
    var favorites: [FavoriteDocument]
    var notebook: [NotebookEntry]
    var images: [BackupImage] = []

    enum CodingKeys: String, CodingKey {
        case schemaVersion, exportedAt, drafts, submissions, reports, favorites, notebook, images
    }

    init(schemaVersion: Int, exportedAt: Date, drafts: [DraftDocument], submissions: [SubmissionDocument], reports: [GradingReportDocument], favorites: [FavoriteDocument], notebook: [NotebookEntry], images: [BackupImage] = []) {
        self.schemaVersion = schemaVersion; self.exportedAt = exportedAt
        self.drafts = drafts; self.submissions = submissions; self.reports = reports
        self.favorites = favorites; self.notebook = notebook; self.images = images
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        drafts = try container.decode([DraftDocument].self, forKey: .drafts)
        submissions = try container.decode([SubmissionDocument].self, forKey: .submissions)
        reports = try container.decode([GradingReportDocument].self, forKey: .reports)
        favorites = try container.decode([FavoriteDocument].self, forKey: .favorites)
        notebook = try container.decode([NotebookEntry].self, forKey: .notebook)
        images = try container.decodeIfPresent([BackupImage].self, forKey: .images) ?? []
    }
}

struct BackupImage: Codable, Equatable {
    var path: String
    var data: Data
}

struct BackupImportSummary: Equatable {
    var drafts = 0
    var submissions = 0
    var reports = 0
    var favorites = 0
    var notebook = 0
    var images = 0

    var added: Int { drafts + submissions + reports + favorites + notebook }
}

enum BackupImportError: LocalizedError {
    case unsupportedVersion
    case invalidImage
    case imageConflict
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "这个备份版本无法读取。请使用较新的 WriteRight 版本。"
        case .invalidImage: return "备份中的原图路径无效，未导入任何内容。"
        case .imageConflict: return "本机已有同名但内容不同的原图。为保护现有练习，未导入任何内容。"
        case .tooLarge: return "备份过大，无法一次导入。请确认文件来自 WriteRight。"
        }
    }
}
