import Foundation

/// Workout state sent from iPhone to Watch for live session UI.
struct WatchWorkoutState: Codable, Sendable {
    let exerciseName: String
    let exerciseID: String
    let currentSet: Int
    let totalSets: Int
    let targetWeight: Double?
    let targetReps: Int?
    let isActive: Bool
}

/// Workout payload sent from Watch to iPhone for persistence.
struct WatchWorkoutUpdate: Codable, Sendable {
    let exerciseID: String
    let exerciseName: String
    var completedSets: [WatchSetData]
    let startTime: Date
    let endTime: Date?
    var heartRateSamples: [WatchHeartRateSample]
}

struct WatchSetData: Codable, Sendable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let isCompleted: Bool
}

struct WatchHeartRateSample: Codable, Sendable {
    let bpm: Double
    let timestamp: Date
}

/// Compact exercise metadata used by Watch UI.
struct WatchExerciseInfo: Codable, Sendable {
    let id: String
    let name: String
    let inputType: String
    let defaultSets: Int
    let defaultReps: Int?
    let defaultWeightKg: Double?
    let equipment: String?
    let cardioSecondaryUnit: String?
}
