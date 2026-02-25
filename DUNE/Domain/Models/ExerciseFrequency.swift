import Foundation

/// Workout type distribution within a time period.
struct ExerciseFrequency: Sendable, Hashable, Identifiable {
    let id: String  // exerciseName
    let exerciseName: String
    let count: Int
    let lastDate: Date?

    /// Fraction of total workouts (0.0-1.0)
    let percentage: Double

    init(exerciseName: String, count: Int, lastDate: Date?, percentage: Double) {
        self.id = exerciseName
        self.exerciseName = exerciseName
        self.count = max(0, count)
        self.lastDate = lastDate
        self.percentage = max(0, min(1.0, percentage))
    }
}
