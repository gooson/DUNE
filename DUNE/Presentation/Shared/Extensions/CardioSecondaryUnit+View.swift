import SwiftUI

extension CardioSecondaryUnit {
    var keyboardType: UIKeyboardType {
        switch self {
        case .km: return .decimalPad
        case .meters, .floors, .count: return .numberPad
        case .none: return .default
        }
    }

    /// Stepper configuration for WorkoutSessionView full-screen input.
    /// Returns nil for `.none` (no secondary field).
    var stepperConfig: (label: String, step: Double, min: Double, max: Double)? {
        switch self {
        case .km:     return ("KM", 0.1, 0, 100)
        case .meters: return ("METERS", 50, 0, 50_000)
        case .floors: return ("FLOORS", 1, 0, 500)
        case .count:  return ("COUNT", 10, 0, 10_000)
        case .none:   return nil
        }
    }

    /// Short suffix for previous-set display in SetRowView.
    var previousSuffix: String {
        switch self {
        case .km: return "k"
        case .meters: return "m"
        case .floors: return "fl"
        case .count: return "x"
        case .none: return ""
        }
    }
}
