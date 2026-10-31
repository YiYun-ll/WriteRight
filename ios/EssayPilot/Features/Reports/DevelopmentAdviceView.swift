import SwiftUI

struct DevelopmentAdviceView: View {
    let advice: [AdvancedAdvice]?
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Divider()
            Text("再往前，试一小步").font(.system(.title2, design: .serif))
            Text("这些是可选择的进阶练法，不代表原稿必须使用复杂句，也不会因为没有采用就扣分。")
                .font(.footnote).foregroundStyle(WriteRightTheme.secondary)
            if let advice, !advice.isEmpty {
                ForEach(["sentence", "structure"], id: \.self) { focus in
                    VStack(alignment: .leading, spacing: 18) {
                        Text(focus == "sentence" ? "让句子更有层次" : "让整篇更有方向")
                            .font(.system(.title3, design: .serif))
                        ForEach(Array(advice.filter { $0.focus == focus }.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(item.observationZH).font(.headline).lineSpacing(4)
                                if !item.before.isEmpty {
                                    Text(item.page.map { "你的片段 · 第 \($0) 页" } ?? "你的片段").font(.caption).foregroundStyle(WriteRightTheme.secondary)
                                    Text(item.before).font(.system(.body, design: .serif)).textSelection(.enabled)
                                }
                                Text("可以这样试").font(.caption).foregroundStyle(WriteRightTheme.accent)
                                Text(item.after).font(.system(.body, design: .serif)).lineSpacing(6).textSelection(.enabled)
                                Text(item.whyZH).font(.subheadline).foregroundStyle(WriteRightTheme.secondary).lineSpacing(5)
                                Label(item.practiceZH, systemImage: "pencil.tip").font(.subheadline).lineSpacing(5)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }.accessibilityIdentifier("advice-" + focus)
                }
            } else {
                GentleNote(text: "这份报告尚未附进阶材料。新批改会结合能看清的原稿，给出句式和篇章练法；早期报告保持原样。")
            }
        }
    }
}
