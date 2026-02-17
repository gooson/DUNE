import Foundation

/// Mode for compound (multi-exercise) workout sessions
enum CompoundWorkoutMode: String, Codable, Sendable, CaseIterable {
    case superset  // 2 exercises alternating
    case circuit   // 3+ exercises cycling through rounds
}

/// Configuration for a compound workout session
struct CompoundWorkoutConfig: Sendable, Identifiable, Hashable {
    let id = UUID()
    let exercises: [ExerciseDefinition]
    let mode: CompoundWorkoutMode
    let totalRounds: Int
    let restBetweenExercises: Int // seconds

    /// Minimum 2 exercises required
    var isValid: Bool {
        exercises.count >= 2 && totalRounds >= 1
    }

    static func == (lhs: CompoundWorkoutConfig, rhs: CompoundWorkoutConfig) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
