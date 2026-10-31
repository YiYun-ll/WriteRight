import SwiftUI

struct ReadingProgressView: View {
    let status: GradingJobState?
    let stage: GradingStage
    var uploadPhase = "preparing"
    var connectionIssue: String? = nil
    var retry: (() -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var note = false

    private var step: Int {
        if status == .completed { return 5 }
        if status == nil { return uploadPhase == "preparing" ? 0 : 1 }
        if status == .queued { return 2 }
        if stage == .evaluate { return 3 }
        return 4
    }
    private var title: String {
        if status == .failed { return "这一页，稍后再接着读" }
        if status == .completed { return "这一篇，已经认真读完" }
        return ["把照片整理好", "正在把原稿送达", "稿子已收好，稍等片刻", "正在读题，也在读你的表达", "把建议一条条放好", "批改完成"][step]
    }
    private var message: String {
        if let connectionIssue { return connectionIssue + " 云端任务会保留，回来时可以继续查看。" }
        if status == .failed { return "照片和任务都还在。重试会接着这一次，不必重新来过。" }
        if status == .completed { return "先看看写得好的地方，再挑一处慢慢修改。" }
        return step < 2 ? "每张照片都会按页放好，题目与作文一起送达。" : "可以先离开，云端会继续处理。回来时，这一页还在。"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).font(.system(.title3, design: .serif)).fixedSize(horizontal: false, vertical: true)
                    Text(message).font(.subheadline).foregroundStyle(WriteRightTheme.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button { withAnimation(reduceMotion ? nil : .easeInOut) { note.toggle() } } label: {
                    Image(systemName: status == .completed ? "leaf" : "cup.and.saucer")
                        .font(.system(size: 26, weight: .ultraLight)).frame(width: 44, height: 44)
                }.buttonStyle(.plain).foregroundStyle(WriteRightTheme.accent).accessibilityLabel("给等待留一句话")
            }
            HStack(spacing: 5) {
                ForEach(0..<5) { index in
                    Capsule().fill(status == .failed ? WriteRightTheme.secondary.opacity(0.18) : index < step ? WriteRightTheme.accent : WriteRightTheme.secondary.opacity(0.16)).frame(height: 5)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: step)
            .accessibilityLabel("处理阶段")
            .accessibilityValue(title)
            if note {
                Text(status == .completed ? "写到这里的人，也值得给自己一点肯定。" : "杯子替你暖着这一小段等待。也记得松一松肩膀。")
                    .font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary).lineSpacing(5)
                    .accessibilityIdentifier("waiting-note")
            }
            if let retry { Button(status == .failed ? "接着这一次重试" : "刷新进度", action: retry).frame(minHeight: 44) }
        }
        .padding(22).frame(maxWidth: .infinity, alignment: .leading)
        .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("reading-progress")
    }
}
