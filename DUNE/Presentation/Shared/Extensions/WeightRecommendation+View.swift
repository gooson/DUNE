import Foundation

extension WeightRecommendation.Reason {
    var displayName: String {
        switch self {
        case .maintain: String(localized: "Keep this weight for the next set.")
        case .insufficientData: String(localized: "Keep this weight until your targets and effort are recorded.")
        case .highEffort: String(localized: "Effort was high. Consider a lighter set.")
        case .missedTarget: String(localized: "The planned reps were not reached. Consider a lighter set.")
        case .readyToProgress: String(localized: "Your completed plan and effort support a small increase.")
        }
    }
}
