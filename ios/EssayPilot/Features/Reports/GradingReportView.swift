import SwiftUI

struct GradingReportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    let document: GradingReportDocument
    @State private var section = "overview"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ReportSectionPicker(selection: $section, photos: document.report.photoReview != nil)
                    .padding(16)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch section {
                        case "sentences":
                            if let photo = document.report.photoReview { photoAdvice(photo) }
                            else if document.report.sentenceReviews == nil { SentenceReportView(document: document) }
                            SentenceReviewView(review: document.report.sentenceReviews)
                            DevelopmentAdviceView(advice: document.report.advancedAdvice)
                        case "rewrites": rewritesView
                        case "review": reviewView
                        default: overviewView
                        }
                    }
                    .padding(20).frame(maxWidth: 720, alignment: .leading)
                }
            }
            .background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
            .navigationTitle("批改报告").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.accessibilityIdentifier("close-report")
                }
            }
            .accessibilityIdentifier("report-view")
        }
    }

    private var overviewView: some View {
        Group {
            VStack(alignment: .leading, spacing: 14) {
                if let value = document.report.score.value {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(value, format: .number.precision(.fractionLength(0...1)))
                            .font(.system(size: 64, weight: .medium, design: .serif))
                        Text("/ \(document.report.score.max)").font(.title3).foregroundStyle(WriteRightTheme.secondary)
                        Spacer()
                        if let band = document.report.score.band { Text(band).font(.title3.weight(.semibold)) }
                    }
                    if let range = document.report.score.range, range.count == 2 {
                        Text("参考区间 \(range[0], format: .number.precision(.fractionLength(0...1)))～\(range[1], format: .number.precision(.fractionLength(0...1))) 分")
                            .font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                    }
                    Text("AI 模拟估分，不代替正式阅卷。").font(.footnote).foregroundStyle(WriteRightTheme.secondary)
                } else {
                    Text("语言批改").font(.largeTitle.weight(.semibold))
                    Text(document.report.photoReview == nil ? "题目未完整确认，因此不提供分数。" : "题面缺失、图片不清或信息不足时，只提供能确认的建议。").font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                }
                if document.report.wordCount > 0 {
                    Text("\(document.report.photoReview == nil ? "" : "约 ")\(document.report.wordCount) 词").font(.subheadline.monospacedDigit()).foregroundStyle(WriteRightTheme.secondary)
                }
            }
            .padding(22).frame(maxWidth: .infinity, alignment: .leading).glassSurface()
            if let photo = document.report.photoReview {
                if !photo.strengths.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("这一篇，值得留下的地方").font(.system(.title3, design: .serif))
                        ForEach(Array(photo.strengths.enumerated()), id: \.offset) { _, item in Text(item).font(.subheadline).lineSpacing(5) }
                    }
                }
                if !photo.uncertainties.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("读图时需要留意").font(.headline)
                        ForEach(Array(photo.uncertainties.enumerated()), id: \.offset) { _, item in
                            Text(item.message).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                        }
                    }
                }
                if photo.sources.contains(where: { $0.role == "task" }) {
                    DisclosureGroup("查看这次的题目原图") {
                        ForEach(photo.sources.filter { $0.role == "task" }) { ReportPhotoView(source: $0).padding(.top, 14) }
                    }.font(.headline)
                }
            }
            GentleNote(text: "分数记录这一次的落点。下一次，先把一处表达写得更清楚就好。")
            Text(document.report.overallComment).font(.body).lineSpacing(5)
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(document.report.dimensions.enumerated()), id: \.offset) { _, dimension in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(dimension.name).font(.headline)
                            Spacer()
                            Text(dimension.level).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                        }
                        Text(dimension.explanation).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                    }
                }
            }
            if !document.report.taskChecks.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("题目要点").font(.title3.weight(.semibold))
                    ForEach(Array(document.report.taskChecks.enumerated()), id: \.offset) { _, check in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: check.status == "passed" ? "checkmark.circle.fill" : "circle.dotted")
                                .foregroundStyle(WriteRightTheme.accent)
                            Text(check.reason).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                        }
                    }
                }
            }
        }
    }

    private func photoAdvice(_ photo: PhotoReviewPayload) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("原稿在这里，建议也在这里。").font(.system(.title3, design: .serif))
            Text("短片段仅用于定位建议；看不清的字以原图为准。可选润色不作为语言错误。").font(.footnote).foregroundStyle(WriteRightTheme.secondary)
            ForEach(photo.sources.filter { $0.role == "essay" }) { source in
                ReportPhotoView(source: source)
                ForEach(Array(photo.corrections.filter { $0.page == source.page && document.report.sentenceReviews == nil }.enumerated()), id: \.offset) { _, correction in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(correction.severity == "required" ? "需要修改 · \(correction.category)" : "可选表达 · \(correction.category)").font(.subheadline.weight(.medium)).foregroundStyle(WriteRightTheme.accent)
                        Text(correction.original).font(.system(.body, design: .serif)).lineSpacing(5)
                        Label { Text(correction.corrected).font(.system(.body, design: .serif)).lineSpacing(5) } icon: { Image(systemName: "arrow.turn.down.right") }
                        Text(correction.reason).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            if photo.corrections.isEmpty && document.report.sentenceReviews == nil { GentleNote(text: "这次没有列出可确认的局部修改。可以结合总览和复盘，选择下一步。") }
        }
    }

    private var rewritesView: some View {
        RewriteReadingView(rewrites: document.report.rewrites, exemplar: document.report.modelEssay)
    }

    private var reviewView: some View {
        Group {
            if !document.report.review.topIssues.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("优先复盘").font(.title3.weight(.semibold))
                    ForEach(Array(document.report.review.topIssues.enumerated()), id: \.offset) { _, issue in
                        Label(issue, systemImage: "arrow.turn.up.right")
                    }
                }
            }
            if !document.report.review.expressions.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("值得积累").font(.title3.weight(.semibold))
                    ForEach(Array(document.report.review.expressions.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.expression).font(.headline)
                                Spacer()
                                let kept = model.isKept(expression: item.expression)
                                Button { model.keep(expression: item, report: document) } label: {
                                    Label(kept ? "已收藏" : "收藏", systemImage: kept ? "bookmark.fill" : "bookmark")
                                        .font(.subheadline.weight(.semibold)).fixedSize().frame(minHeight: 44)
                                }
                                .disabled(kept)
                                .accessibilityIdentifier("keep-expression")
                            }
                            Text(item.meaning).font(.subheadline)
                            Text(item.usage).font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary)
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("下一次练习").font(.title3.weight(.semibold))
                Text(document.report.review.practiceAdvice).lineSpacing(5)
            }
        }
    }
}

private struct SentenceReportView: View {
    let document: GradingReportDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(document.sentences) { sentence in
                let correction = document.report.corrections.first { $0.sentenceID == sentence.id }
                VStack(alignment: .leading, spacing: 12) {
                    Text(sentence.original)
                        .font(.system(.body, design: .serif)).lineSpacing(6)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(correction == nil ? Color.clear : WriteRightTheme.soft, in: RoundedRectangle(cornerRadius: 12))
                    if let correction {
                        if correction.severity == "required" {
                            Text(correction.minimalCorrected)
                                .font(.system(.body, design: .serif).weight(.medium)).lineSpacing(6)
                        }
                        Text("\(correction.category) · \(correction.reasonZH)")
                            .font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                        if let upgrade = correction.optionalUpgrade, !upgrade.isEmpty {
                            Text(upgrade).font(.system(.body, design: .serif)).lineSpacing(6)
                        }
                    }
                }
                if sentence.id != document.sentences.last?.id { Divider() }
            }
        }
    }
}

private struct ReportSectionPicker: View {
    @Binding var selection: String
    @Environment(\.dynamicTypeSize) private var typeSize
    var photos = false
    private var sections: [(String, String)] { [("overview", "总览"), ("sentences", photos ? "原稿建议" : "逐句"), ("rewrites", "修改稿"), ("review", "复盘")] }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: typeSize.isAccessibilitySize ? 2 : 4), spacing: 4) {
            ForEach(sections, id: \.0) { key, title in
                Button { selection = key } label: {
                    Text(title).font(.subheadline.weight(selection == key ? .semibold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.vertical, typeSize.isAccessibilitySize ? 8 : 0)
                        .background(selection == key ? WriteRightTheme.surface : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("report-section-" + key)
                .accessibilityAddTraits(selection == key ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(WriteRightTheme.soft, in: RoundedRectangle(cornerRadius: 16))
    }
}
