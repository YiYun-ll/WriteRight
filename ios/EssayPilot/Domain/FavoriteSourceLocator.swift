import Foundation

enum FavoriteSourceLocator {
    static func sentence(for expression: ReviewExpression, in report: GradingReportDocument) -> String {
        let phrase = FavoriteDocument.normalize(expression.expression)
        guard !phrase.isEmpty else { return "" }
        var phrases = [phrase]
        if phrase.hasPrefix("be ") { phrases.append(String(phrase.dropFirst(3))) }
        func contains(_ text: String) -> Bool {
            let normalized = FavoriteDocument.normalize(text)
            return phrases.contains { normalized.contains($0) }
        }
        if let exact = report.sentences.first(where: { contains($0.original) }) { return exact.original }

        if let correction = report.report.corrections.first(where: {
            contains($0.original) || contains($0.minimalCorrected) || contains($0.optionalUpgrade ?? "")
        }) {
            return report.sentences.first(where: { $0.id == correction.sentenceID })?.original ?? correction.original
        }
        if let review = report.report.sentenceReviews?.items.first(where: {
            contains($0.original) || contains($0.revised ?? "")
        }) { return review.original }
        if let correction = report.report.photoReview?.corrections.first(where: {
            contains($0.original) || contains($0.corrected)
        }) { return correction.original }
        return ""
    }
}
