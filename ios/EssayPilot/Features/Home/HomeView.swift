import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let onCreate: (WritingPart, WritingTaskDocument?) -> Void
    let onOpen: (DraftDocument) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(WritingPart.allCases) { part in
                        PartEntry(part: part) { onCreate(part, nil) }
                    }
                }
                let drafts = model.drafts.filter { !$0.isEmpty }
                if !drafts.isEmpty {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("继续写").font(.title2.weight(.semibold))
                        VStack(spacing: 0) {
                            ForEach(Array(drafts.prefix(3).enumerated()), id: \.element.id) { index, draft in
                                if index > 0 { Divider().padding(.leading, 20) }
                                Button { onOpen(draft) } label: {
                                    HStack(spacing: 16) {
                                        DraftRow(draft: draft)
                                        Image(systemName: "chevron.right").font(.caption.weight(.bold))
                                            .foregroundStyle(WriteRightTheme.secondary)
                                    }.padding(.horizontal, 20).padding(.vertical, 8)
                                }.buttonStyle(.plain)
                            }
                        }.background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 22))
                    }
                }
            }.padding(.horizontal, 24).padding(.top, 15).padding(.bottom, 32)
        }
        .background(WriteRightTheme.background)
        .foregroundStyle(WriteRightTheme.ink)
        .navigationTitle("WriteRight")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(WritingPart.allCases) { part in
                        Button(part.title) { onCreate(part, nil) }
                    }
                } label: { Image(systemName: "square.and.pencil").frame(width: 44, height: 44) }
                    .accessibilityLabel("新建练习")
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: typeSize.isAccessibilitySize ? 1 : 2)
    }
}

struct PracticeView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    let onCreate: (WritingPart, WritingTaskDocument?) -> Void

    private var tasks: [WritingTaskDocument] {
        var seen = Set<UUID>()
        return model.drafts.filter { !$0.isEmpty }.compactMap { seen.insert($0.task.id).inserted ? $0.task : nil }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 14) {
                    ForEach(WritingPart.allCases) { part in PartEntry(part: part) { onCreate(part, nil) } }
                }
                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("再写一稿").font(.title2.weight(.semibold))
                        ForEach(tasks) { task in
                            Button { onCreate(task.part, task) } label: {
                                HStack(spacing: 16) {
                                    Text(task.part.rawValue).font(.system(.title, design: .serif))
                                        .frame(width: 34).foregroundStyle(WriteRightTheme.accent)
                                    Text(task.displayTitle).font(.headline).foregroundStyle(WriteRightTheme.ink)
                                        .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: "arrow.up.right").foregroundStyle(WriteRightTheme.secondary)
                                }.padding(20).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.padding(24)
        }.background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink).navigationTitle("练习")
    }
}
