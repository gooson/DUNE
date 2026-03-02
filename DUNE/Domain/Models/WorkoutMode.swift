import Foundation

/// Workout mode: strength (weight x reps) or cardio (distance+pace).
/// Referenced by WorkoutManager, WorkoutRecoveryState, and test targets.
enum WorkoutMode: Sendable, Codable {
    case strength
    case cardio(activityType: WorkoutActivityType, isOutdoor: Bool)

    var isCardio: Bool {
        if case .cardio = self { return true }
        return false
    }
}
