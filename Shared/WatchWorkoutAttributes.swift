import ActivityKit
import Foundation

struct WatchWorkoutAttributes: ActivityAttributes {
    typealias ContentState = WatchWorkoutSnapshot
    var mirrorID: UUID
}
