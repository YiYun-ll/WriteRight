import SwiftUI
import UIKit

struct TranslationScoreBreakdown: View {
    let review: TranslationReview
    let score: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !review.noticeZH.isEmpty {
                Label(review.noticeZH, systemImage: "exclamationmark.bubble")
                    .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            }
            if let score {
                Text("得分依据").font(.title3.weight(.semibold))
                ForEach(review.sentences) { sentence in
                    HStack(alignment: .firstTextBaseline) {
                        Text("第 \(sentence.index) 句")
                        Spacer()
                        Text("\(sentence.earned.formatted()) / \(sentence.maximum.formatted())")
                            .monospacedDigit()
                    }.font(.subheadline)
                }
                Divider()
                Text("各句合计 \(review.subtotal.formatted()) − 错别字扣分 \(review.typoDeduction.formatted()) = \(score.formatted()) / 15")
                    .font(.subheadline.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                Text("采分点为练习模拟划分，不是官方标准。错别字按全文累计，每满 3 个扣 0.5 分，余 1–2 个扣 0.25 分；已扣误译分的不重复计算。")
                    .font(.footnote).foregroundStyle(WriteRightTheme.secondary)
            }
            ForEach(Array(review.typos.enumerated()), id: \.offset) { _, typo in
                Text("\(typo.original) → \(typo.corrected)：\(typo.reason)").font(.subheadline)
            }
        }.accessibilityIdentifier("translation-score-breakdown")
    }
}

struct TranslationSentenceList: View {
    let review: TranslationReview
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !review.noticeZH.isEmpty { GentleNote(text: review.noticeZH) }
            ForEach(review.sentences) { sentence in
                TranslationSentenceCard(sentence: sentence)
            }
            if review.sentences.isEmpty { GentleNote(text: "暂时没有可确认的逐句建议，请根据提示补充英文原文或清晰照片。") }
        }.accessibilityIdentifier("translation-sentences")
    }
}

private struct TranslationSentenceCard: View {
    let sentence: TranslationReview.Sentence
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("第 \(sentence.index) 句").font(.headline)
                Spacer()
                if sentence.status == "uncertain" { Text("待辨认").font(.subheadline) }
                else { Text("\(sentence.earned.formatted()) / \(sentence.maximum.formatted())").monospacedDigit() }
            }
            if sentence.sourcePage != nil || sentence.answerPage != nil {
                Text([sentence.sourcePage.map { "原文第 \($0) 页" }, sentence.answerPage.map { "译文第 \($0) 页" }].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(WriteRightTheme.secondary)
            }
            passage("英文原句", sentence.english)
            passage("我的译文", sentence.student.isEmpty ? "此句未作答" : sentence.student)
            VStack(alignment: .leading, spacing: 14) {
                Text("采分点").font(.subheadline.weight(.semibold))
                ForEach(Array(sentence.points.enumerated()), id: \.offset) { _, point in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(point.meaning)（\(point.earned.map { $0.formatted() } ?? "待定") / \(point.max.formatted())）").font(.subheadline.weight(.medium))
                        Text(point.explanation).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                    }
                }
            }
            passage("问题解释", sentence.analysis)
            passage("句子结构与译法", sentence.structure)
            if !sentence.revised.isEmpty { passage("修改译文", sentence.revised) }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .textSelection(.enabled)
    }
    private func passage(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(WriteRightTheme.secondary)
            Text(text).font(.system(.body, design: .serif)).lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TranslationRevisionView: View {
    let review: TranslationReview
    @State private var copied = false
    private var emphasized: AttributedString {
        var result = AttributedString(review.revisedTranslation)
        for change in review.changes {
            if let range = result.range(of: change.text) { result[range].font = .body.bold() }
        }
        return result
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("完整修改译文").font(.title2.weight(.semibold))
            if review.revisedTranslation.isEmpty {
                GentleNote(text: review.noticeZH.isEmpty ? "信息不足，暂不提供完整修改译文。" : review.noticeZH)
            } else {
                Text(emphasized).font(.system(.body, design: .serif)).lineSpacing(8).textSelection(.enabled)
                    .accessibilityIdentifier("translation-revision")
                Button(copied ? "已复制" : "复制译文", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = review.revisedTranslation; copied = true
                }.frame(minHeight: 44).accessibilityIdentifier("translation-copy")
                if !review.changes.isEmpty {
                    Divider()
                    Text("主要修改").font(.headline)
                    ForEach(Array(review.changes.enumerated()), id: \.offset) { _, change in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(change.text).font(.body.bold())
                            Text(change.reasonZH).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                        }
                    }
                }
            }
        }
    }
}
