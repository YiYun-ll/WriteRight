import Foundation

/// Sends this device's cat to the account and keeps whatever the merge returns.
/// Growth only ever unions, so a lost response or a retry can never take anything away.
@MainActor enum CompanionSync {
    /// Returns true when another device added something this one did not have.
    @discardableResult
    static func sync(userID: UUID, store: CompanionStore, transport: any SyncTransport, now: Date = .now) async throws -> Bool {
        let owner = userID.uuidString
        let sent = (store.load(owner: owner) ?? CompanionState(metAt: now)).growth
        let account = try await transport.mergeCompanion(userID: userID, growth: sent)
        // Taps made while the request was in flight are merged in, not overwritten.
        var latest = store.load(owner: owner) ?? CompanionState(metAt: now)
        let merged = account.merged(with: latest.growth)
        let learned = merged != latest.growth
        latest.growth = merged
        latest.needsUpload = merged != account
        store.save(latest, owner: owner)
        return learned
    }
}
