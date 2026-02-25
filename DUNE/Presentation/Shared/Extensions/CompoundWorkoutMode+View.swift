import Foundation

extension CompoundWorkoutMode {
    var displayName: String {
        switch self {
        case .superset: "Superset"
        case .circuit: "Circuit"
        }
    }
}
