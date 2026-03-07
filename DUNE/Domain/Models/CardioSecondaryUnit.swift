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

    /// Whether this cardio unit represents a machine-driven session where
    /// elapsed time is automatic and the user controls intensity via machine level.
    var supportsMachineLevel: Bool {
        switch self {
        case .floors, .timeOnly:
            return true
        case .km, .meters, .count:
            return false
        }
    }

    /// Machine-driven cardio sessions should default to indoor-only start flows.
    var isIndoorOnly: Bool {
        supportsMachineLevel
    }

    /// Allowed machine level range for supported cardio sessions.
    var machineLevelRange: ClosedRange<Int>? {
        guard supportsMachineLevel else { return nil }
        return 1...20
    }

    /// Clamps the provided machine level into the supported range.
    func normalizedMachineLevel(_ value: Int?) -> Int? {
        guard let value, let range = machineLevelRange else { return nil }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    /// Returns a normalized 0.0-1.0 intensity score derived from the average level.
    func normalizedMachineLevelScore(_ averageLevel: Double?) -> Double? {
        guard let averageLevel, let range = machineLevelRange else { return nil }
        let lower = Double(range.lowerBound)
        let span = Double(range.upperBound - range.lowerBound)
        guard span > 0 else { return nil }
        return min(max((averageLevel - lower) / span, 0), 1)
    }

    /// Reuses the existing stair-climber multiplier curve for machine cardio MET adjustment.
    func metMultiplier(forMachineLevel level: Int?) -> Double {
        guard supportsMachineLevel, let level = normalizedMachineLevel(level) else { return 1.0 }
        return min(max(Double(level) / 5.0, 0.5), 2.0)
    }
}
