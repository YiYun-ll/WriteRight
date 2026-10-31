import SwiftUI

struct SentenceReviewView: View {
    let review: SentenceReviews?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("逐句修改").font(.system(.title2, design: .serif)).accessibilityIdentifier("sentence-review-heading")
            Text("一句一句看，也看看哪些表达值得保留。可选表达不等于原句有错。")
                .font(.subheadline).foregroundStyle(WriteRightTheme.secondary).lineSpacing(5)
            if let review {
                if review.coverage != "complete" || !review.noticeZH.isEmpty {
                    GentleNote(text: review.noticeZH.isEmpty ? "这里是能确认的部分，请结合原图核对。" : review.noticeZH)
                }
                ForEach(review.items) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("第 \(item.index) 句\(item.page.map { " · 第 \($0) 页" } ?? "")")
                                .font(.subheadline.weight(.medium))
                            Spacer(minLength: 8)
                            Text(status(item.status)).font(.caption).foregroundStyle(WriteRightTheme.accent)
                        }
                        if !item.original.isEmpty {
                            Text("原句").font(.caption).foregroundStyle(WriteRightTheme.secondary)
                            Text(item.original).font(.system(.body, design: .serif)).lineSpacing(6).textSelection(.enabled)
                        }
                        if let revised = item.revised, !revised.isEmpty, item.status != "keep", item.status != "uncertain" {
                            Text(item.status == "optional" ? "也可以这样写" : "建议修改")
                                .font(.caption).foregroundStyle(WriteRightTheme.accent)
                            Text(revised).font(.system(.body, design: .serif)).lineSpacing(6).textSelection(.enabled)
                        }
                        Text("为什么").font(.caption.weight(.medium))
                        Text(item.reasonZH).font(.subheadline).foregroundStyle(WriteRightTheme.secondary).lineSpacing(5)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityIdentifier("sentence-review-\(item.index)")
                }
            } else {
                GentleNote(text: "这份早期报告未附逐句说明。原有建议仍可查看；新批改会按句给出修改与理由。")
            }
        }.accessibilityIdentifier("sentence-reviews")
    }
    private func status(_ value: String) -> String {
        switch value {
        case "required": "需要修改"
        case "optional": "可选表达"
        case "uncertain": "需要核对"
        default: "值得保留"
        }
    }
}
