import Foundation

/// Per-set weight+reps snapshot for PR calculation (no SwiftData dependency).
struct SetSnapshot: Sendable {
    let weight: Double
    let reps: Int
}

/// Lightweight snapshot of an exercise/workout record without SwiftData dependency.
struct ExerciseRecordSnapshot: Sendable {
    let date: Date
    let exerciseDefinitionID: String?
    let exerciseName: String?
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let completedSetCount: Int
    /// Total training volume across all completed sets (sum of weight × reps, in kg). nil for bodyweight or unknown.
    let totalWeight: Double?
    /// Total reps across all sets. nil for time-based or unknown.
    let totalReps: Int?
    /// Workout duration in minutes. Used for cardio load calculation.
    let durationMinutes: Double?
    /// Distance in kilometers. Used for cardio load calculation.
    let distanceKm: Double?
    /// Per-set weight+reps for 1RM / rep-max / volume PR calculation.
    let completedSetSnapshots: [SetSnapshot]

    init(
        date: Date,
        exerciseDefinitionID: String? = nil,
        exerciseName: String? = nil,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup],
        completedSetCount: Int,
        totalWeight: Double? = nil,
        totalReps: Int? = nil,
        durationMinutes: Double? = nil,
        distanceKm: Double? = nil,
        completedSetSnapshots: [SetSnapshot] = []
    ) {
        self.date = date
        self.exerciseDefinitionID = exerciseDefinitionID
        self.exerciseName = exerciseName
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.completedSetCount = completedSetCount
        self.totalWeight = totalWeight
        self.totalReps = totalReps
        self.durationMinutes = durationMinutes
        self.distanceKm = distanceKm
        self.completedSetSnapshots = completedSetSnapshots
    }
}
