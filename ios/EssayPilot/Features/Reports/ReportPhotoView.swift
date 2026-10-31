import SwiftUI
import UIKit

/// Original images remain the source of truth. Failure never substitutes a generated transcript.
struct ReportPhotoView: View {
    @EnvironmentObject private var app: AppModel
    let source: PhotoSource
    @State private var image: UIImage?
    @State private var failed = false
    @State private var attempt = 0
    @State private var zoom = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(source.role == "task" ? "题目" : "作文") · 第 \(source.page) 页").font(.subheadline).foregroundStyle(WriteRightTheme.secondary)
            if let image {
                Button { zoom = true } label: {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 320)
                }.buttonStyle(.plain).accessibilityLabel("放大\(source.role == "task" ? "题目" : "作文")第\(source.page)页")
            } else if failed {
                Button("原图暂未取回，点此重试") { failed = false; attempt += 1 }.frame(minHeight: 44)
            } else { ProgressView("正在取回原图").frame(maxWidth: .infinity, minHeight: 100) }
        }
        .task(id: attempt) {
            do {
                let data = try await app.gradingPhoto(source)
                guard !Task.isCancelled, let decoded = UIImage(data: data) else { failed = true; return }
                image = decoded
            } catch { if !Task.isCancelled { failed = true } }
        }
        .sheet(isPresented: $zoom) { if let image { ScanZoomView(image: image, lines: [], highlighted: nil) } }
    }
}

struct GentleNote: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "leaf").font(.title3.weight(.ultraLight)).foregroundStyle(WriteRightTheme.accent).accessibilityHidden(true)
            Text(text).font(.system(.subheadline, design: .serif)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(WriteRightTheme.soft, in: RoundedRectangle(cornerRadius: 18))
    }
}
