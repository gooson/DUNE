import Foundation

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
    /// Time-only cardio — no secondary field shown or stored (e.g. Elliptical).
    /// rawValue "none" is CloudKit/JSON-persisted; rename requires migration. (Correction #164)
    case timeOnly = "none"

    /// Convert user input to internal storage unit (km). Returns nil for non-distance units.
    func toKm(_ value: Double) -> Double? {
        switch self {
        case .km: return value
        case .meters: return value / 1000.0
        case .floors, .count, .timeOnly: return nil
        }
    }

    /// Whether this unit stores its value in `WorkoutSet.reps` instead of `distance`.
    var usesRepsField: Bool {
        switch self {
        case .floors, .count: return true
        case .km, .meters, .timeOnly: return false
        }
    }

    /// Whether this unit stores its value in `WorkoutSet.distance` (as km).
    var usesDistanceField: Bool {
        switch self {
        case .km, .meters: return true
        case .floors, .count, .timeOnly: return false
        }
    }

    /// UI placeholder text (Foundation only — no SwiftUI import).
    var placeholder: String {
        switch self {
        case .km: return "km"
        case .meters: return "m"
        case .floors: return "floors"
        case .count: return "count"
        case .timeOnly: return ""
        }
    }

    /// Validation range for user input. Returns nil for `.timeOnly`.
    var validationRange: ClosedRange<Double>? {
        switch self {
        case .km: return 0.1...500
        case .meters: return 1...50_000
        case .floors: return 1...500
        case .count: return 1...10_000
        case .timeOnly: return nil
        }
    }
}
