import SwiftUI
import Charts

struct FavoritesView: View {
    @EnvironmentObject private var model: AppModel
    @StateObject private var removal = PendingRemoval()
    private var visible: [FavoriteDocument] { model.favorites.filter { !removal.hides($0.id) } }

    var body: some View {
        Group {
            if visible.isEmpty {
                ContentUnavailableView("还没有收藏", systemImage: "bookmark")
            } else {
                List {
                    ForEach(visible) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.expression).font(.headline)
                            if !item.meaning.isEmpty { Text(item.meaning).font(.subheadline) }
                            if !item.usage.isEmpty {
                                Text(item.usage).font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary)
                            }
                            if let sentence = item.sources.last?.sentence, !sentence.isEmpty {
                                Text(sentence).font(.caption).foregroundStyle(WriteRightTheme.secondary)
                            }
                            Text("\(item.sources.count) 处来源").font(.caption).foregroundStyle(WriteRightTheme.secondary)
                        }
                        .padding(.vertical, 8)
                        .swipeActions {
                            Button("删除", role: .destructive) {
                                removal.remove(id: item.id, message: "已移除收藏「\(item.expression)」") { model.deleteFavorite(id: item.id) }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped).scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
        .navigationTitle("收藏")
        .undoableRemoval(removal, account: model.account?.userID)
    }
}

struct PracticeStatsView: View {
    @EnvironmentObject private var model: AppModel
    private var points: [ScorePoint] { PracticeAnalytics.points(submissions: model.submissions, reports: model.gradingReports) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("一篇一篇，留下自己的刻度。").font(.system(.title2, design: .serif))
                if points.isEmpty {
                    GentleNote(text: "还没有可展示的估分。完成有完整题图的批改后，第一枚刻度就会留在这里。仅语言反馈的练习也会保存在历史里。")
                }
                ForEach(WritingPart.allCases) { part in
                    let series = points.filter { $0.part == part }
                    if !series.isEmpty { scoreCard(series, part: part) }
                }
                GentleNote(text: "进步有时是分数上升，有时是终于知道该改哪里。练习的价值，都在其中。")
            }.padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        }.background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink).navigationTitle("成绩")
    }
    private func scoreCard(_ series: [ScorePoint], part: WritingPart) -> some View {
        let latest = series.last!
        let same = series.filter { $0.rubricVersion == latest.rubricVersion }
        let prior = same.dropLast().last
        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text(part.title).font(.system(.title3, design: .serif)); Spacer()
                Text("\(series.count) 次估分").font(.caption).foregroundStyle(WriteRightTheme.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(latest.score.formatted()).font(.system(size: 48, weight: .medium, design: .serif))
                Text("/ \(part.maximumScore)").foregroundStyle(WriteRightTheme.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text("最近一次").font(.caption)
                    Text(latest.date, format: .dateTime.month().day().locale(Locale(identifier: "zh_CN"))).font(.caption.monospacedDigit())
                }.foregroundStyle(WriteRightTheme.secondary)
            }
            if same.count >= 2 {
                Chart {
                    ForEach(Array(same.enumerated()), id: \.element.submissionID) { index, point in
                        LineMark(x: .value("练习", index + 1), y: .value("估分", point.score)).foregroundStyle(WriteRightTheme.accent)
                        PointMark(x: .value("练习", index + 1), y: .value("估分", point.score)).foregroundStyle(WriteRightTheme.accent)
                    }
                }.chartYScale(domain: 0...Double(part.maximumScore))
                    .chartXScale(domain: 0.7...(Double(same.count) + 0.3))
                    .chartXAxis {
                        AxisMarks(values: Array(Set([1, same.count] + Array(stride(from: 1, through: same.count, by: max(1, same.count / 4))))).sorted()) { value in
                            AxisValueLabel { if let index = value.as(Int.self) { Text("第\(index)次") } }
                        }
                    }.frame(height: 160)
                    .accessibilityLabel("\(part.title)成绩趋势，采用最近一次相同评分标准")
            }
            Text(prior.map { latest.score > $0.score ? "比上一次多走了一点。记住这次用对的方法。" : latest.score == $0.score ? "落在同一个刻度，也可以把注意力放在更清楚的表达上。" : "这次的起伏，是下一次练习的线索。先挑报告里的一处建议。" } ?? "第一枚刻度已经留下。下一次，从这一次的建议开始。")
                .font(.system(.subheadline, design: .serif)).lineSpacing(5)
            if !PracticeAnalytics.comparable(series) { Text("图表只连接同一评分标准的记录。旧标准记录保留在下方。").font(.footnote).foregroundStyle(WriteRightTheme.secondary) }
            Divider()
            ForEach(series.reversed(), id: \.submissionID) { point in
                HStack {
                    Text(point.date, format: .dateTime.month().day().locale(Locale(identifier: "zh_CN"))).font(.subheadline)
                    Spacer()
                    Text("\(point.score.formatted()) / \(point.max)").font(.subheadline.monospacedDigit())
                }
            }
            Text("AI 模拟估分，题目难度会影响结果；小作文、大作文与翻译分别记录。").font(.footnote).foregroundStyle(WriteRightTheme.secondary)
        }.padding(22).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct TaskCompareView: View {
    @EnvironmentObject private var model: AppModel
    @State private var report: GradingReportDocument?
    private var pairs: [TaskComparison] {
        var seen = Set<UUID>()
        return model.submissions.compactMap { submission in
            guard let pair = PracticeAnalytics.comparison(taskID: submission.task.id, submissions: model.submissions, reports: model.gradingReports), seen.insert(pair.right.id).inserted else { return nil }
            return pair
        }.sorted { $0.right.submittedAt > $1.right.submittedAt }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("回头看，也是一种向前。").font(.system(.title2, design: .serif))
                if pairs.isEmpty { GentleNote(text: "同一道题再写一次，就能把两次表达放在一起。照片练习请复用同一张题图；我们只在同一题型、同一评分标准下比较分数。") }
                ForEach(pairs, id: \.right.id) { pair in
                    VStack(alignment: .leading, spacing: 20) {
                        Text(pair.right.task.displayTitle).font(.system(.title3, design: .serif))
                        if pair.comparable {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(score(pair.leftScore))  →  \(score(pair.rightScore))").font(.system(.largeTitle, design: .serif))
                                Text("/ \(pair.right.task.part.maximumScore)").foregroundStyle(WriteRightTheme.secondary)
                            }
                        } else { Text("这两次只对照原稿和建议，不比较总分。").font(.footnote).foregroundStyle(WriteRightTheme.secondary) }
                        GentleNote(text: "再写一次，已经多了一次把想法说清楚的机会。对照时先找一处变好的表达，再选一处继续练。")
                        comparisonPage(pair.left, title: "上一次")
                        Divider()
                        comparisonPage(pair.right, title: "这一次")
                    }.padding(22).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                }
            }.padding(24).frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        }.background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink).navigationTitle("同题对比")
            .fullScreenCover(item: $report) { GradingReportView(document: $0) }
    }
    private func comparisonPage(_ submission: SubmissionDocument, title: String) -> some View {
        let result = model.gradingReports.first { $0.submissionID == submission.id }
        return VStack(alignment: .leading, spacing: 12) {
            HStack { Text(title).font(.headline); Spacer(); Text(submission.submittedAt, format: .dateTime.month().day().locale(Locale(identifier: "zh_CN"))).font(.caption).foregroundStyle(WriteRightTheme.secondary) }
            if let photo = result?.report.photoReview {
                ForEach(photo.sources.filter { $0.role == "essay" }) { ReportPhotoView(source: $0, translation: submission.task.part == .translation) }
            } else { Text(submission.originalText).font(.system(.subheadline, design: .serif)).lineSpacing(5).lineLimit(8) }
            if let result {
                Text(result.report.overallComment).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                Button("打开这次的完整报告") { report = result }.frame(minHeight: 44)
            }
        }
    }
    private func score(_ value: Double?) -> String { value.map { $0.formatted() } ?? "无总分" }
}
