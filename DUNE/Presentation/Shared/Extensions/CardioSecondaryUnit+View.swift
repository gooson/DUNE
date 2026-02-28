import SwiftUI

extension CardioSecondaryUnit {
    var keyboardType: UIKeyboardType {
        switch self {
        case .km: return .decimalPad
        case .meters, .floors, .count: return .numberPad
        case .timeOnly: return .default
        }
    }

    /// Stepper configuration for WorkoutSessionView full-screen input.
    /// Min/max derived from `validationRange` — single source of truth.
    /// Returns nil for `.timeOnly` (no secondary field).
    var stepperConfig: (label: String, step: Double, min: Double, max: Double)? {
        guard self != .timeOnly, let range = validationRange else { return nil }
        let step: Double = switch self {
        case .km: 0.1
        case .meters: 50
        case .floors: 1
        case .count: 10
        case .timeOnly: return nil
        }
        return (placeholder.uppercased(), step, range.lowerBound, range.upperBound)
    }

    /// Short suffix for previous-set display in SetRowView.
    var previousSuffix: String {
        switch self {
        case .km: return "k"
        case .meters: return "m"
        case .floors: return "fl"
        case .count: return "x"
        case .timeOnly: return ""
        }
    }
}
