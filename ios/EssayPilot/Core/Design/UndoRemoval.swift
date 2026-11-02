import SwiftUI

/// Hides a swiped row at once and only deletes it when the undo window closes, so an undo can
/// never race a sync that is already pushing the deletion.
@MainActor final class PendingRemoval: ObservableObject {
    struct Item: Equatable { let ids: Set<UUID>; let message: String }
    @Published private(set) var item: Item?
    private var commit: (() -> Void)?
    private var timer: Task<Void, Never>?
    let window: Duration

    init(window: Duration = .seconds(5)) { self.window = window }

    func remove(id: UUID, message: String, commit: @escaping () -> Void) {
        remove(ids: [id], message: message, commit: commit)
    }

    func remove(ids: Set<UUID>, message: String, commit: @escaping () -> Void) {
        finish()
        item = Item(ids: ids, message: message); self.commit = commit
        AccessibilityNotification.Announcement("\(message)，可以撤销").post()
        timer = Task { [weak self, window] in
            try? await Task.sleep(for: window)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }
    func undo() { timer?.cancel(); timer = nil; commit = nil; item = nil }
    /// Commits now: leaving the screen or the app keeps the user's decision.
    func finish() {
        timer?.cancel(); timer = nil
        let action = commit; commit = nil; item = nil
        action?()
    }
    func hides(_ id: UUID) -> Bool { item?.ids.contains(id) == true }
}

struct UndoRemovalBar: View {
    @ObservedObject var removal: PendingRemoval
    var body: some View {
        if let item = removal.item {
            HStack {
                Text(item.message).font(.subheadline).lineLimit(2)
                Spacer(minLength: 12)
                Button("撤销") { removal.undo() }.font(.subheadline.weight(.semibold))
                    .foregroundStyle(WriteRightTheme.accent)
                    .frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("undo-removal")
            }
            .padding(.horizontal, 20).padding(.vertical, 4)
            .background(WriteRightTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .padding(.horizontal, 16).padding(.bottom, 8)
            .foregroundStyle(WriteRightTheme.ink)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

extension View {
    /// Shows the undo bar and commits pending removals when the screen goes away or the account changes hands.
    func undoableRemoval(_ removal: PendingRemoval, account: UUID?) -> some View {
        modifier(UndoRemovalModifier(removal: removal, account: account))
    }
}

private struct UndoRemovalModifier: ViewModifier {
    @ObservedObject var removal: PendingRemoval
    let account: UUID?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) { UndoRemovalBar(removal: removal) }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: removal.item)
            .onDisappear { removal.finish() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { removal.finish() } }
            // The pending delete belongs to the previous account's store; dropping it keeps that data safe.
            .onChange(of: account) { _, _ in removal.undo() }
    }
}
