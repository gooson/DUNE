import Foundation

extension CompoundWorkoutMode {
    var displayName: String {
        switch self {
        case .superset: String(localized: "Superset")
        case .circuit: String(localized: "Circuit")
        }
    }
}
