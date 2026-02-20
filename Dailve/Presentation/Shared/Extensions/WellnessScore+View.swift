import SwiftUI

extension WellnessScore.Status {
    var label: String {
        switch self {
        case .excellent: "Excellent"
        case .good:      "Good"
        case .fair:      "Fair"
        case .tired:     "Tired"
        case .warning:   "Warning"
        }
    }

    var color: Color {
        switch self {
        case .excellent: DS.Color.wellnessExcellent
        case .good:      DS.Color.wellnessGood
        case .fair:      DS.Color.wellnessFair
        case .tired:     DS.Color.scoreTired
        case .warning:   DS.Color.wellnessWarning
        }
    }

    var iconName: String {
        switch self {
        case .excellent: "checkmark.circle.fill"
        case .good:      "hand.thumbsup.fill"
        case .fair:      "minus.circle.fill"
        case .tired:     "moon.fill"
        case .warning:   "exclamationmark.triangle.fill"
        }
    }
}
