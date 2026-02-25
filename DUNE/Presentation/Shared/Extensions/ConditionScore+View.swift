import SwiftUI

extension ConditionScore.Status {
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
