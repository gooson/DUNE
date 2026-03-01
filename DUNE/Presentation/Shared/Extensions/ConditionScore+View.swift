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

    /// The color of the next tier this score is heading toward.
    var nextTierColor: Color {
        switch self {
        case .warning:   DS.Color.scoreTired
        case .tired:     DS.Color.scoreFair
        case .fair:      DS.Color.scoreGood
        case .good:      DS.Color.scoreExcellent
        case .excellent: DS.Color.scoreExcellent.exposureAdjust(2)
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
