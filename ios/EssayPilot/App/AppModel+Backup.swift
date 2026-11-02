import Foundation

@MainActor extension AppModel {
    func exportURL() throws -> URL {
        guard let repository else { throw LocalStoreError.unavailable }
        var backup = try JSONDecoder().decode(WritingBackup.self, from: repository.exportData())
        backup.schemaVersion = WritingBackup.currentVersion
        let store = try scanImageStore()
        var paths = Set<String>()
        for draft in backup.drafts {
            for page in (draft.pages ?? []) + (draft.task.sourcePages ?? []) {
                paths.insert(page.relativePath)
                if let path = page.uploadRelativePath { paths.insert(path) }
            }
        }
        for submission in backup.submissions {
            for page in (submission.essayPages ?? []) + (submission.task.sourcePages ?? []) {
                paths.insert(page.relativePath)
                if let path = page.uploadRelativePath { paths.insert(path) }
            }
        }
        backup.images = paths.sorted().compactMap { path in
            guard let url = store.url(path), let data = try? Data(contentsOf: url) else { return nil }
            return BackupImage(path: path, data: data)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WriteRight-练习备份.json")
        try encoder.encode(backup).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    func exportReportURL(_ report: GradingReportDocument) throws -> URL {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WriteRight-\(report.part.title)-\(report.createdAt.timeIntervalSince1970).json")
        try encoder.encode(report).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    func importBackup(data: Data) throws -> BackupImportSummary {
        guard data.count <= 1_000_000_000 else { throw BackupImportError.tooLarge }
        let backup = try JSONDecoder().decode(WritingBackup.self, from: data)
        guard (3...WritingBackup.currentVersion).contains(backup.schemaVersion) else { throw BackupImportError.unsupportedVersion }
        guard backup.images.count <= 20_000, backup.images.reduce(0, { $0 + $1.data.count }) <= 1_000_000_000 else { throw BackupImportError.tooLarge }
        let imageStore = try scanImageStore()
        for image in backup.images {
            guard let url = imageStore.url(image.path) else { throw BackupImportError.invalidImage }
            if let existing = try? Data(contentsOf: url), existing != image.data { throw BackupImportError.imageConflict }
        }
        guard let repository else { throw LocalStoreError.unavailable }
        var summary = BackupImportSummary()
        for image in backup.images {
            guard let id = UUID(uuidString: String(image.path.dropLast(4))), let url = imageStore.url(image.path) else { throw BackupImportError.invalidImage }
            if !FileManager.default.fileExists(atPath: url.path) {
                _ = try imageStore.save(data: image.data, id: id)
                summary.images += 1
            }
        }

        var draftIDs: [UUID: UUID] = [:]
        var tasks: [UUID: WritingTaskDocument] = [:]
        var knownDrafts = drafts
        for original in backup.drafts {
            var document = original
            if let existing = knownDrafts.first(where: { $0.id == original.id }) {
                if existing == original {
                    draftIDs[original.id] = original.id; tasks[original.task.id] = original.task
                    continue
                }
                document.id = UUID()
                if existing.task != original.task { document.task.id = UUID() }
            }
            try repository.save(document)
            knownDrafts.append(document)
            draftIDs[original.id] = document.id; tasks[original.task.id] = document.task
            summary.drafts += 1
        }

        var submissionIDs: [UUID: UUID] = [:]
        var knownSubmissions = submissions
        for original in backup.submissions {
            let task = tasks[original.task.id] ?? original.task
            var document = SubmissionDocument(
                id: original.id, draftID: draftIDs[original.draftID] ?? original.draftID, task: task,
                originalText: original.originalText, wordCount: original.wordCount, contentHash: original.contentHash,
                sentences: original.sentences, submittedAt: original.submittedAt, essayPages: original.essayPages
            )
            if let existing = knownSubmissions.first(where: { $0.id == original.id }) {
                if existing == document {
                    submissionIDs[original.id] = original.id
                    continue
                }
                document = SubmissionDocument(
                    id: UUID(), draftID: document.draftID, task: document.task, originalText: document.originalText,
                    wordCount: document.wordCount, contentHash: document.contentHash, sentences: document.sentences,
                    submittedAt: document.submittedAt, essayPages: document.essayPages
                )
            }
            try repository.saveSubmission(document)
            knownSubmissions.append(document); submissionIDs[original.id] = document.id
            summary.submissions += 1
        }

        var reportIDs: [UUID: UUID] = [:]
        let knownReports = try repository.gradingReportChanges().map(\.report)
        for original in backup.reports {
            let submissionID = submissionIDs[original.submissionID] ?? original.submissionID
            var document = GradingReportDocument(
                id: original.id, jobID: submissionID == original.submissionID ? original.jobID : UUID(),
                submissionID: submissionID, part: original.part, report: original.report,
                sentences: original.sentences, createdAt: original.createdAt
            )
            if let existing = knownReports.first(where: { $0.id == original.id }) {
                if existing == document {
                    reportIDs[original.id] = original.id
                    continue
                }
                document = GradingReportDocument(
                    id: UUID(), jobID: document.jobID, submissionID: document.submissionID,
                    part: document.part, report: document.report, sentences: document.sentences, createdAt: document.createdAt
                )
            }
            try repository.saveGradingReport(document)
            reportIDs[original.id] = document.id
            summary.reports += 1
        }

        let knownFavorites = try repository.favoriteChanges().map(\.favorite)
        for original in backup.favorites {
            var document = original
            document.deletedAt = nil
            document.sources = original.sources.map { source in
                FavoriteSource(reportID: reportIDs[source.reportID] ?? source.reportID, sentence: source.sentence)
            }
            if let existing = knownFavorites.first(where: { $0.id == original.id }), existing != document,
               !knownFavorites.contains(where: { $0.normalized == document.normalized }) {
                document.id = UUID()
            }
            try repository.keepFavorite(document)
            summary.favorites += 1
        }

        var knownNotes = try repository.notebookChanges().map(\.entry)
        for original in backup.notebook {
            var document = original; document.deletedAt = nil
            if let existing = knownNotes.first(where: { $0.id == original.id }) {
                if existing == document { continue }
                document.id = UUID()
            }
            try repository.saveNotebook(document)
            knownNotes.append(document); summary.notebook += 1
        }
        refresh()
        return summary
    }
}
