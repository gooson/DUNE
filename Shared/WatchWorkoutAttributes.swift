import ActivityKit
import Foundation

struct WatchWorkoutAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var snapshot: WatchWorkoutSnapshot
        var preferences: WorkoutLiveActivityPreferences

        init(snapshot: WatchWorkoutSnapshot, preferences: WorkoutLiveActivityPreferences) {
            self.snapshot = snapshot
            self.preferences = preferences
        }

        private enum CodingKeys: String, CodingKey {
            case snapshot, preferences
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.snapshot) {
                snapshot = try container.decode(WatchWorkoutSnapshot.self, forKey: .snapshot)
                preferences = try container.decode(WorkoutLiveActivityPreferences.self, forKey: .preferences)
            } else {
                // Activities created by earlier app versions encoded the snapshot directly.
                snapshot = try WatchWorkoutSnapshot(from: decoder)
                preferences = WorkoutLiveActivityPreferences()
            }
        }
    }
    var mirrorID: UUID
}
