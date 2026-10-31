import Foundation

struct OCRLineDocument: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let confidence: Float
    let alternatives: [String]
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct ScanPageDocument: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var relativePath: String
    var rawText: String
    var correctedText: String
    var lines: [OCRLineDocument]
    var confirmed: Bool
    var transcriptionSource: String? = nil
    var uncertainties: [String]? = nil
    var uploadRelativePath: String? = nil
}

struct ChartFactDocument: Codable, Identifiable, Equatable {
    var id: String
    var label: String
    var period: String?
    var value: String
    var unit: String
    var confidence: String
    var confirmedByUser: Bool
    enum CodingKeys: String, CodingKey {
        case id, label, period, value, unit, confidence
        case confirmedByUser = "confirmed_by_user"
    }
}

struct ParsedTaskDocument: Codable {
    struct Point: Codable { let id: String; var description: String }
    struct WordRequirement: Codable { let target: Int; let min: Int?; let max: Int?; let source: String }
    var part: WritingPart
    var promptType: String
    var genre: String
    var requiredPoints: [Point]
    var chartFacts: [ChartFactDocument]
    var wordRequirement: WordRequirement
    var uncertainFields: [String]
    enum CodingKeys: String, CodingKey {
        case part, genre
        case promptType = "prompt_type", requiredPoints = "required_points", chartFacts = "chart_facts"
        case wordRequirement = "word_requirement", uncertainFields = "uncertain_fields"
    }
}
struct ParsedTaskResponse: Codable {
    let parsed: ParsedTaskDocument
    let parserVersion: String
    let modelID: String
}

struct ImageTranscriptionResponse: Decodable {
    let text: String
    let uncertain: [String]
    let transcriberVersion: String
    let modelID: String
}

struct PhotoAnalysisResponse: Decodable {
    struct TaskResult: Decodable {
        let prompt: String
        let parsed: ParsedTaskDocument
    }
    struct Page: Decodable {
        let text: String
        let uncertain: [String]
    }
    let task: TaskResult?
    let essayPages: [Page]
    let analysisVersion: String
    let modelID: String
}
