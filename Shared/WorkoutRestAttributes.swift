import ActivityKit
import Foundation

struct WorkoutRestAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var endDate: Date
        var totalDuration: Int
    }

    var sessionStartedAt: Date
    var exerciseName: String
    var setNumber: Int
}
