import Foundation
import Supabase

protocol GradingService: Sendable {
    func submitPhotos(taskID: UUID, part: WritingPart, submissionID: UUID, idemKey: UUID, taskImages: [Data], essayImages: [Data]) async throws -> GradingStatusResponse
    func photoData(_ source: PhotoSource) async throws -> Data
    func submit(task: WritingTaskDocument, submissionID: UUID, originalText: String, idemKey: UUID) async throws -> GradingStatusResponse
    func transcribeImage(_ image: Data) async throws -> ImageTranscriptionResponse
    func analyzePhotos(part: WritingPart, taskImages: [Data], essayImages: [Data]) async throws -> PhotoAnalysisResponse
    func status(jobID: UUID) async throws -> GradingStatusResponse
    func parseTask(part: WritingPart, text: String, images: [Data]) async throws -> ParsedTaskResponse
}

extension GradingService {
    func submitPhotos(taskID: UUID, part: WritingPart, submissionID: UUID, idemKey: UUID, taskImages: [Data], essayImages: [Data]) async throws -> GradingStatusResponse { throw GradingServiceError.invalidResponse }
    func photoData(_ source: PhotoSource) async throws -> Data { throw GradingServiceError.invalidResponse }
    func analyzePhotos(part: WritingPart, taskImages: [Data], essayImages: [Data]) async throws -> PhotoAnalysisResponse { throw GradingServiceError.invalidResponse }
    func transcribeImage(_ image: Data) async throws -> ImageTranscriptionResponse { throw GradingServiceError.invalidResponse }
    func parseTask(part: WritingPart, text: String, images: [Data]) async throws -> ParsedTaskResponse { throw GradingServiceError.invalidResponse }
}

enum GradingServiceError: Error {
    case http(Int, String)
    case invalidResponse
}

private struct GradingErrorResponse: Decodable {
    struct Detail: Decodable { let code: String }
    let error: Detail
}

struct SupabaseGradingService: GradingService {
    private let client: SupabaseClient
    private let baseURL: URL
    private let key: String

    init?(client: SupabaseClient, bundle: Bundle = .main) {
        guard let rawURL = BackendConfiguration.value("SUPABASE_URL", bundle: bundle),
              let key = BackendConfiguration.value("SUPABASE_PUBLISHABLE_KEY", bundle: bundle),
              let url = URL(string: rawURL), !key.isEmpty else { return nil }
        self.client = client; self.key = key
        baseURL = url.appendingPathComponent("functions/v1")
    }

    func submit(task: WritingTaskDocument, submissionID: UUID, originalText: String, idemKey: UUID) async throws -> GradingStatusResponse {
        struct Input: Encodable {
            struct Task: Encodable {
                struct Point: Encodable { let id: String; let text: String }
                let id: UUID
                let part: WritingPart
                let title: String
                let prompt: String
                let requirements: [Point]
                let revision: Int
                let confirmed: Bool
                let chartFacts: [ChartFactDocument]
            }
            struct Submission: Encodable { let id: UUID; let originalText: String }
            let idemKey: UUID
            let task: Task
            let submission: Submission
        }
        let input = Input(
            idemKey: idemKey,
            task: .init(
                id: task.id, part: task.part, title: task.title, prompt: task.prompt,
                requirements: task.requirements.map { .init(id: $0.id, text: $0.text) },
                revision: task.revision, confirmed: task.isConfirmed, chartFacts: task.chartFacts ?? []
            ),
            submission: .init(id: submissionID, originalText: originalText)
        )
        return try await request("submit-grading", method: "POST", body: input)
    }

    func submitPhotos(taskID: UUID, part: WritingPart, submissionID: UUID, idemKey: UUID, taskImages: [Data], essayImages: [Data]) async throws -> GradingStatusResponse {
        struct Input: Encodable {
            struct Topic: Encodable { let id: UUID; let part: WritingPart }
            struct Submission: Encodable { let id: UUID }
            let idemKey: UUID; let task: Topic; let submission: Submission
            let taskImages: [String]; let essayImages: [String]
        }
        func inline(_ data: Data) -> String { "data:image/jpeg;base64," + data.base64EncodedString() }
        return try await request("submit-photo-grading", method: "POST", body: Input(idemKey: idemKey, task: .init(id: taskID, part: part), submission: .init(id: submissionID), taskImages: taskImages.map(inline), essayImages: essayImages.map(inline)))
    }

    func photoData(_ source: PhotoSource) async throws -> Data {
        let session = try await client.auth.session
        guard source.path.lowercased().hasPrefix(session.user.id.uuidString.lowercased() + "/"), !source.path.contains("..") else { throw GradingServiceError.invalidResponse }
        let root = baseURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("storage/v1/object/authenticated/essay-images")
        let url = source.path.split(separator: "/").reduce(root) { $0.appendingPathComponent(String($1)) }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey"); request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, ContentFingerprint.hash(data) == source.checksum else { throw GradingServiceError.invalidResponse }
        return data
    }

    func status(jobID: UUID) async throws -> GradingStatusResponse {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "jobId", value: jobID.uuidString)]
        return try await request("grading-status", method: "GET", query: components.percentEncodedQuery)
    }

    func parseTask(part: WritingPart, text: String, images: [Data]) async throws -> ParsedTaskResponse {
        struct Input: Encodable { let part: WritingPart; let text: String; let images: [String] }
        return try await request("parse-task", method: "POST", body: Input(part: part, text: text, images: images.map { "data:image/jpeg;base64," + $0.base64EncodedString() }))
    }

    func transcribeImage(_ image: Data) async throws -> ImageTranscriptionResponse {
        struct Input: Encodable { let image: String }
        return try await request("transcribe-image", method: "POST", body: Input(image: "data:image/jpeg;base64," + image.base64EncodedString()))
    }

    func analyzePhotos(part: WritingPart, taskImages: [Data], essayImages: [Data]) async throws -> PhotoAnalysisResponse {
        struct Input: Encodable { let part: WritingPart; let taskImages: [String]; let essayImages: [String] }
        func inline(_ data: Data) -> String { "data:image/jpeg;base64," + data.base64EncodedString() }
        return try await request("analyze-photos", method: "POST", body: Input(part: part, taskImages: taskImages.map(inline), essayImages: essayImages.map(inline)))
    }

    private func request<T: Decodable>(_ path: String, method: String, body: (any Encodable)? = nil, query: String? = nil) async throws -> T {
        let session = try await client.auth.session
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw GradingServiceError.invalidResponse
        }
        components.percentEncodedQuery = query
        guard let url = components.url else { throw GradingServiceError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = ["analyze-photos", "submit-photo-grading"].contains(path) ? 120 : 60
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            request.httpBody = try encoder.encode(body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GradingServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? JSONDecoder().decode(GradingErrorResponse.self, from: data).error.code) ?? "HTTP_\(http.statusCode)"
            throw GradingServiceError.http(http.statusCode, code)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { container in
            let text = try container.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "Invalid date"))
            }
            return date
        }
        return try decoder.decode(T.self, from: data)
    }
}

#if DEBUG
actor UITestGradingService: GradingService {
    private var photos: [String: Data] = [:]
    func photoData(_ source: PhotoSource) async throws -> Data {
        guard let data = photos[source.path] else { throw GradingServiceError.invalidResponse }; return data
    }
    func submitPhotos(taskID: UUID, part: WritingPart, submissionID: UUID, idemKey: UUID, taskImages: [Data], essayImages: [Data]) async throws -> GradingStatusResponse {
        try await Task.sleep(for: .milliseconds(800))
        var sources: [PhotoSource] = []
        for (role, data) in [("task", taskImages), ("essay", essayImages)] {
            for (index, bytes) in data.enumerated() {
                let path = "synthetic/\(submissionID)/\(role)-\(index).jpg"
                photos[path] = bytes
                sources.append(.init(role: role, page: index + 1, path: path, checksum: ContentFingerprint.hash(bytes)))
            }
        }
        var task = WritingTaskDocument.empty(part: part); task.id = taskID
        if !taskImages.isEmpty { task.prompt = "Synthetic invitation"; task.confirmedAt = .now }
        let photo = PhotoReviewPayload(sources: sources, taskFingerprint: taskImages.isEmpty ? nil : "fixture", taskStatus: taskImages.isEmpty ? "missing" : "readable", strengths: ["邀请的目的表达得很清楚。"], uncertainties: [], corrections: [.init(page: 1, original: "I has", corrected: "I have", reason: "主语为 I 时使用 have。", category: "主谓一致", severity: "required")], wordCountEstimated: true)
        return Self.completed(task: task, submissionID: submissionID, originalText: "", jobID: idemKey, photo: photo)
    }

    func analyzePhotos(part: WritingPart, taskImages: [Data], essayImages: [Data]) async throws -> PhotoAnalysisResponse {
        let parsed = ParsedTaskDocument(part: part, promptType: "situational", genre: "letter", requiredPoints: [.init(id: "p1", description: "Invite Alex to a museum visit.")], chartFacts: [], wordRequirement: .init(target: part.suggestedWords, min: nil, max: nil, source: "default_guideline"), uncertainFields: [])
        return .init(task: taskImages.isEmpty ? nil : .init(prompt: "Write a letter to Alex to invite him to a museum visit.", parsed: parsed), essayPages: essayImages.map { _ in .init(text: "Dear Alex,\n\nI has a book. It is useful.\n\nYours,\nLi Ming", uncertain: []) }, analysisVersion: "TEST", modelID: "synthetic-ui")
    }

    func submit(task: WritingTaskDocument, submissionID: UUID, originalText: String, idemKey: UUID) async throws -> GradingStatusResponse {
        Self.completed(task: task, submissionID: submissionID, originalText: originalText, jobID: idemKey)
    }

    func status(jobID: UUID) async throws -> GradingStatusResponse {
        throw GradingServiceError.invalidResponse
    }

    private static func completed(task: WritingTaskDocument, submissionID: UUID, originalText: String, jobID: UUID, photo: PhotoReviewPayload? = nil) -> GradingStatusResponse {
        let sentences = SentenceSegmenter.sentences(in: originalText)
        let first = sentences.first
        let corrected = first?.original.replacingOccurrences(of: "has", with: "have") ?? first?.original
        let minimum = photo == nil ? originalText.replacingOccurrences(of: "has", with: "have") : "I have a book. It is useful."
        let important = SentenceSegmenter.sentences(in: minimum).first?.original ?? minimum
        let reading = RewriteStudyVersion(translationZH: "我有一本书。它很有用。", highlights: important.isEmpty ? [] : [.init(text: important, reasonZH: "主语与谓语搭配准确；先把一句话写清楚。")])
        let payload = GradingReportPayload(
            schemaVersion: photo == nil ? "1.3.0" : "2.3.0", part: task.part, gradingMode: task.isConfirmed ? "full" : "language_only",
            score: .init(value: task.isConfirmed ? 8 : nil, max: task.part.maximumScore, band: task.isConfirmed ? (task.part == .a ? "良好" : "中等") : nil, range: task.isConfirmed ? [7, 9] : nil, confidence: "medium"),
            wordCount: WordCounter.count(originalText), rubricVersion: "TEST", promptVersion: "TEST", modelID: "synthetic-ui",
            overallComment: "结构完整，注意主谓一致。",
            dimensions: [
                .init(name: "内容与任务", level: "良好", explanation: "覆盖了主要任务。", evidenceSentenceIDs: first.map { [$0.id] } ?? []),
                .init(name: "语言", level: "中等", explanation: "有一处需要修改。", evidenceSentenceIDs: first.map { [$0.id] } ?? []),
                .init(name: "组织", level: "良好", explanation: "表达清楚。", evidenceSentenceIDs: [])
            ],
            taskChecks: task.requirements.map { .init(pointID: $0.id, status: "passed", reason: "已覆盖。", evidenceSentenceIDs: first.map { [$0.id] } ?? []) },
            corrections: first.map {
                [.init(sentenceID: $0.id, original: $0.original, minimalCorrected: corrected ?? $0.original, category: "主谓一致", severity: "required", impact: "medium", reasonZH: "主语为 I 时使用 have。", optionalUpgrade: nil)]
            } ?? [],
            rewrites: .init(minimal: minimum, enhanced: minimum, study: .init(minimal: reading, enhanced: reading)),
            review: .init(topIssues: ["主谓一致"], expressions: [.init(expression: "be useful for", meaning: "对……有用", usage: "Reading is useful for learning.")], practiceAdvice: "复核每句的主语和谓语。"), photoReview: photo,
            sentenceReviews: .init(coverage: "complete", noticeZH: "", items: photo == nil ? sentences.enumerated().map { index, sentence in
                .init(index: index + 1, sentenceID: sentence.id, page: nil, original: sentence.original, revised: index == 0 ? (corrected ?? sentence.original) : sentence.original, status: index == 0 && corrected != sentence.original ? "required" : "keep", reasonZH: index == 0 && corrected != sentence.original ? "主语I使用have，先把主谓搭配写准确。" : "句子信息清楚，保留原来的表达。")
            } : [
                .init(index: 1, sentenceID: nil, page: 1, original: "I has a book.", revised: "I have a book.", status: "required", reasonZH: "主语I使用have，has用于第三人称单数；这里先把主谓搭配写准确。"),
                .init(index: 2, sentenceID: nil, page: 1, original: "It is useful.", revised: "It is useful.", status: "keep", reasonZH: "主系表结构完整，直接说明用途，不必为了复杂而改写。"),
            ]),
            advancedAdvice: [
                .init(focus: "sentence", observationZH: "把两句之间的关系写清楚", before: photo == nil ? (first?.original ?? "") : "I has a book.", after: "I have a book that helps me understand the world.", whyZH: "定语从句让补充信息贴近它所说明的名词；是否需要使用仍取决于原意。", practiceZH: "找一句短句，先确认主干，再加一句有依据的说明。", page: photo == nil ? nil : 1),
                .init(focus: "structure", observationZH: "让段落各有自己的任务", before: "", after: "State the purpose. Explain the details. Close with a clear next step.", whyZH: "读者先知道为什么写，再理解细节，最后看到下一步。", practiceZH: "用中文给每段标一个作用，看看是否有重复。", page: nil)
            ],
            modelEssay: task.isConfirmed ? .init(english: "Dear Alex,\n\nI am writing to invite you to visit the museum with me. It would be a chance to discover how everyday objects tell the stories of a city.\n\nWe could begin with the history exhibition and then explore the room that interests you most. Rather than rush through every display, we can take time to discuss what we notice. Please let me know whether you would like to join me, and we can arrange a suitable time.\n\nI look forward to sharing this experience with you.\n\nYours,\nLi Ming", translationZH: "亲爱的Alex：\n\n我写信邀请你和我一起参观博物馆。这将是一次了解日常物件如何讲述城市故事的机会。\n\n我们可以先看历史展览，再去你最感兴趣的展厅。我们可以慢慢讨论看到的内容，而不必匆匆看完每一件展品。请告诉我你是否愿意同行，我们再商量合适的时间。\n\n期待与你分享这次经历。\n\n你的，\n李明", highlights: [.init(text: "Rather than rush through every display, we can take time to discuss what we notice.", reasonZH: "Rather than引导对比，让参观方式和安排更具体。")], rationaleZH: "这是合成界面测试中的示范稿。开头说明目的，中段展开安排，结尾邀请回应；示范不等于真实考试得分。") : nil
        )
        let report = GradingReportDocument(
            id: jobID, jobID: jobID,
            submissionID: submissionID, part: task.part, report: payload, sentences: sentences, createdAt: .now
        )
        return .init(jobId: jobID, status: .completed, stage: .done, report: report, errorCode: nil)
    }
}
#endif
