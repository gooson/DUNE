import Foundation

enum ExerciseCategory: String, Codable, CaseIterable, Sendable {
    case strength
    case cardio
    case hiit
    case flexibility
    case bodyweight

    var displayName: String {
        switch self {
        case .strength: "Strength"
        case .cardio: "Cardio"
        case .hiit: "HIIT"
        case .flexibility: "Flexibility"
        case .bodyweight: "Bodyweight"
        }
    }

    /// Default `WorkoutActivityType` for this category (no HealthKit dependency).
    /// For finer resolution, use `WorkoutActivityType.infer(from: exerciseName)` first.
    var defaultActivityType: WorkoutActivityType {
        switch self {
        case .strength:    .traditionalStrengthTraining
        case .cardio:      .mixedCardio
        case .hiit:        .highIntensityIntervalTraining
        case .flexibility: .flexibility
        case .bodyweight:  .functionalStrengthTraining
        }
    }
}

enum ExerciseInputType: String, Codable, Sendable {
    /// Strength: sets x reps x weight (kg)
    case setsRepsWeight
    /// Bodyweight: sets x reps (weight optional)
    case setsReps
    /// Cardio: duration + distance
    case durationDistance
    /// Flexibility: duration + intensity (1-10)
    case durationIntensity
    /// HIIT: rounds x time + rest
    case roundsBased
}

enum SetType: String, Codable, Sendable {
    case warmup
    case working
    case drop
    case failure
    case interval
    case rest
}

/// Secondary unit for cardio exercises (durationDistance input type).
/// Determines how the non-duration field is displayed and stored.
enum CardioSecondaryUnit: String, Codable, Sendable, CaseIterable {
    /// Kilometers — Running, Walking, Cycling, Hiking, Stationary Bike
    case km
    /// Meters — Swimming, Rowing Machine
    case meters
    /// Floors/stories — Stair Climber
    case floors
    /// Repetition count — Jump Rope
    case count
    /// No secondary field — Elliptical (time only)
    case none

    /// Convert user input to internal storage unit (km). Returns nil for non-distance units.
    func toKm(_ value: Double) -> Double? {
        switch self {
        case .km: return value
        case .meters: return value / 1000.0
        case .floors, .count, .none: return nil
        }
    }

    /// Whether this unit stores its value in `WorkoutSet.reps` instead of `distance`.
    var usesRepsField: Bool {
        switch self {
        case .floors, .count: return true
        case .km, .meters, .none: return false
        }
    }

    /// Whether this unit stores its value in `WorkoutSet.distance` (as km).
    var usesDistanceField: Bool {
        switch self {
        case .km, .meters: return true
        case .floors, .count, .none: return false
        }
    }

    /// UI placeholder text (Foundation only — no SwiftUI import).
    var placeholder: String {
        switch self {
        case .km: return "km"
        case .meters: return "m"
        case .floors: return "floors"
        case .count: return "count"
        case .none: return ""
        }
    }

    /// Validation range for user input. Returns nil for `.none`.
    var validationRange: ClosedRange<Double>? {
        switch self {
        case .km: return 0.1...500
        case .meters: return 1...50_000
        case .floors: return 1...500
        case .count: return 1...10_000
        case .none: return nil
        }
    }
}

enum CalorieSource: String, Codable, Sendable {
    case healthKit
    case met
    case manual
}
