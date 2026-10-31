import SwiftUI
import UIKit

struct RewriteReadingView: View {
    let rewrites: ReportRewrites
    var exemplar: ModelEssay? = nil
    @State private var version = "minimal"
    @State private var showTranslation = true
    @State private var showHighlights = true
    @State private var copied = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var english: String { version == "model" ? (exemplar?.english ?? "") : version == "minimal" ? rewrites.minimal : rewrites.enhanced }
    private var study: RewriteStudyVersion? { version == "model" ? exemplar?.study : version == "minimal" ? rewrites.study?.minimal : rewrites.study?.enhanced }
    private var highlights: [RewriteHighlight] { study?.validHighlights(in: english) ?? [] }
    private var markedEnglish: AttributedString {
        var value = AttributedString(english)
        if showHighlights {
            for item in highlights {
                if let range = value.range(of: item.text) {
                    value[range].foregroundColor = WriteRightTheme.emphasisRed
                    value[range].inlinePresentationIntent = .stronglyEmphasized
                }
            }
        }
        return value
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if typeSize.isAccessibilitySize {
                versionPicker.pickerStyle(.menu).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            } else { versionPicker.pickerStyle(.segmented) }
            Text(version == "model" ? "AI独立创作的满分档示范，帮助理解布局和表达；不保证真实考试满分。" : version == "minimal" ? "保留你的表达，先把必要的地方写准确。" : "在保留原意的基础上，看看另一种更顺的表达。")
                .font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary).lineSpacing(5)
            if english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                GentleNote(text: version == "model" ? "这份报告没有独立示范作文。只有完整题面和关键信息足够清楚时，新批改才会提供；不会用作文反推题目。" : "这次的信息不足以支持完整改写。先把关键页面拍清楚，再一起往下走。")
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 20) { readingControls }
                    VStack(alignment: .leading, spacing: 8) { readingControls }
                }.font(.subheadline).buttonStyle(.borderless)
                VStack(alignment: .leading, spacing: 16) {
                    Text(version == "model" ? "AI 示范作文" : "英文修改稿").font(.headline)
                    Text(markedEnglish).font(.system(.body, design: .serif)).lineSpacing(8)
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("rewrite-english")
                }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                if !highlights.isEmpty && showHighlights {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("重点句，慢慢读").font(.system(.title3, design: .serif))
                        Text("红色表示值得复习，不表示这句话有错。").font(.footnote).foregroundStyle(WriteRightTheme.secondary)
                        ForEach(Array(highlights.enumerated()), id: \.offset) { index, item in
                            VStack(alignment: .leading, spacing: 7) {
                                Text("重点 \(index + 1)").font(.caption.weight(.semibold)).foregroundStyle(WriteRightTheme.emphasisRed)
                                Text(item.text).font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.emphasisRed).lineSpacing(5)
                                Text(item.reasonZH).font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
                            }.accessibilityElement(children: .combine)
                        }
                    }.accessibilityIdentifier("rewrite-highlights")
                }
                if showTranslation {
                    if let study, !study.translationZH.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("中文译文").font(.headline)
                            Text(study.translationZH).font(.system(.body, design: .serif)).lineSpacing(7)
                                .textSelection(.enabled).accessibilityIdentifier("rewrite-translation")
                        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                            .background(WriteRightTheme.soft.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
                    } else {
                        Text("这份早期报告未附中文译文。新批改会同时提供两种修改稿的中英对照与重点句。")
                            .font(.footnote).foregroundStyle(WriteRightTheme.secondary).accessibilityIdentifier("rewrite-legacy-note")
                    }
                }
                if version == "model", let exemplar { GentleNote(text: exemplar.rationaleZH) }
                Text("修改稿和译文均为学习参考，请对照原稿检查事实与读图疑点。")
                    .font(.footnote).foregroundStyle(WriteRightTheme.secondary)
            }
        }.task(id: copied) {
            if copied { try? await Task.sleep(for: .seconds(2)); if !Task.isCancelled { copied = false } }
        }.onChange(of: version) { _, _ in copied = false }
    }
    private var versionPicker: some View {
        Picker("修改方式", selection: $version) {
            Text("最小修改").tag("minimal")
            Text("表达增强").tag("enhanced")
            Text("满分示范").tag("model")
        }.accessibilityIdentifier("rewrite-version")
    }
    @ViewBuilder private var readingControls: some View {
        if let study, !study.translationZH.isEmpty {
            Button { showTranslation.toggle() } label: {
                Label("中文对照", systemImage: showTranslation ? "character.book.closed.fill" : "character.book.closed")
            }.frame(minHeight: 44).accessibilityValue(showTranslation ? "已显示" : "已隐藏").accessibilityIdentifier("rewrite-toggle-translation")
        }
        if !highlights.isEmpty {
            Button { showHighlights.toggle() } label: { Label("重点句", systemImage: showHighlights ? "highlighter" : "text.alignleft") }
                .frame(minHeight: 44).accessibilityValue(showHighlights ? "已标出" : "已隐藏").accessibilityIdentifier("rewrite-toggle-highlights")
        }
        Button { UIPasteboard.general.string = english; copied = true } label: { Label(copied ? "已复制" : "复制英文", systemImage: copied ? "checkmark" : "doc.on.doc") }
            .frame(minHeight: 44).accessibilityIdentifier("rewrite-copy")
    }
}
