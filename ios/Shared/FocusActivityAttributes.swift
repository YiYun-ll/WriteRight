import ActivityKit
import Foundation

struct FocusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var name: String
        var endsAt: Date
    }
    var startedAt: Date
}
