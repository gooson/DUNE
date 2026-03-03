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
    var rpe: Int?
}

struct WatchSetData: Codable, Sendable {
    let setNumber: Int
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let restDuration: TimeInterval?
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

/// Lightweight workout template payload sent from iPhone to Watch.
/// Used as a fallback sync path when CloudKit template propagation is delayed/disabled.
struct WatchWorkoutTemplateInfo: Codable, Sendable {
    let id: UUID
    let name: String
    let entries: [TemplateEntry]
    let updatedAt: Date
}
