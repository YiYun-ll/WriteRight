import ActivityKit
import Foundation

@MainActor protocol FocusActivityControlling {
    func start(name: String, startedAt: Date, endsAt: Date)
    func finish(name: String, endsAt: Date)
}

@MainActor final class FocusActivityController: FocusActivityControlling {
    static let shared = FocusActivityController()
    private init() {}

    func start(name: String, startedAt: Date, endsAt: Date) {
        let state = FocusActivityAttributes.ContentState(name: name, endsAt: endsAt)
        let content = ActivityContent(state: state, staleDate: endsAt)
        if let current = Activity<FocusActivityAttributes>.activities.first(where: { $0.attributes.startedAt == startedAt }) {
            Task { await current.update(content) }
            return
        }
        for activity in Activity<FocusActivityAttributes>.activities {
            Task { await activity.end(content, dismissalPolicy: .immediate) }
        }
        _ = try? Activity<FocusActivityAttributes>.request(
            attributes: FocusActivityAttributes(startedAt: startedAt), content: content, pushType: nil
        )
    }

    func finish(name: String, endsAt: Date) {
        let content = ActivityContent(state: FocusActivityAttributes.ContentState(name: name, endsAt: endsAt), staleDate: nil)
        for activity in Activity<FocusActivityAttributes>.activities {
            Task { await activity.end(content, dismissalPolicy: .immediate) }
        }
    }
}
