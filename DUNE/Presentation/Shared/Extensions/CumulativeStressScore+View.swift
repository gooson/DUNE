import SwiftUI

extension CumulativeStressScore.Level {
    var color: Color {
        switch self {
        case .low: DS.Color.positive
        case .moderate: DS.Color.warning
        case .elevated: .orange
        case .high: DS.Color.negative
        }
    }

    var iconName: String {
        switch self {
        case .low: "checkmark.circle"
        case .moderate: "exclamationmark.circle"
        case .elevated: "exclamationmark.triangle"
        case .high: "exclamationmark.triangle.fill"
        }
    }
}
