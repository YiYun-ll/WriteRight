import SwiftUI

/// The private note remains separate from the single interactive desk at the top of Home.
struct HomePrivateNoteView: View {
    @StateObject private var companion: DeskCompanionModel
    @State private var editing = false
    init(owner: String) {
        _companion = StateObject(wrappedValue: DeskCompanionModel(owner: owner))
    }
    var body: some View {
        Button { editing = true } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "square.and.pencil").font(.title3.weight(.ultraLight)).foregroundStyle(WriteRightTheme.accent)
                VStack(alignment: .leading, spacing: 7) {
                    Text(companion.note.isEmpty ? "给自己留张便笺" : "留给自己的话").font(.headline)
                    Text(companion.note.isEmpty ? "一句小事，或一句想对自己说的话。" : companion.note)
                        .font(.system(.subheadline, design: .serif)).foregroundStyle(WriteRightTheme.secondary).lineLimit(3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(WriteRightTheme.secondary)
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("home-private-note")
            .sheet(isPresented: $editing) { noteEditor }
    }
    private var noteEditor: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("不用写得漂亮，写给自己就好。").font(.system(.title3, design: .serif))
                    TextField("今天想留住的一句话…", text: Binding(get: { companion.note }, set: { companion.note = String($0.prefix(280)) }), axis: .vertical)
                        .lineLimit(5...10).font(.system(.body, design: .serif)).lineSpacing(6)
                        .padding(20).background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityIdentifier("desk-note-text")
                    Text("只留在这台设备的当前账号中，不参与批改或云同步。可以随时改写或清空，最多280字。")
                        .font(.footnote).foregroundStyle(WriteRightTheme.secondary)
                    if !companion.note.isEmpty { Button("清空便笺", role: .destructive) { companion.clear() }.frame(minHeight: 44).accessibilityIdentifier("desk-note-clear") }
                }.padding(24)
            }.background(WriteRightTheme.background).foregroundStyle(WriteRightTheme.ink)
                .navigationTitle("口袋便笺").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("收好") { editing = false }.accessibilityIdentifier("desk-note-done") } }
        }
    }
}
