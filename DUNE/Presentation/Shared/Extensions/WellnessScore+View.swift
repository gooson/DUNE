import SwiftUI

extension WellnessScore.Status {
    var label: String {
        switch self {
        case .excellent: String(localized: "Excellent")
        case .good:      String(localized: "Good")
        case .fair:      String(localized: "Fair")
        case .tired:     String(localized: "Tired")
        case .warning:   String(localized: "Warning")
        }
    }

    var color: Color {
        switch self {
        case .excellent: DS.Color.scoreExcellent
        case .good:      DS.Color.scoreGood
        case .fair:      DS.Color.scoreFair
        case .tired:     DS.Color.scoreTired
        case .warning:   DS.Color.scoreWarning
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
