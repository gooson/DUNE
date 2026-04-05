import SwiftUI

extension CumulativeStressScore.Level {
    var color: Color {
        switch self {
        case .low: DS.Color.positive
        case .moderate: DS.Color.caution
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

extension CumulativeStressScore.Contribution.Factor {
    var color: Color {
        switch self {
        case .hrvVariability: DS.Color.hrv
        case .sleepConsistency: DS.Color.sleep
        case .activityLoad: DS.Color.activity
        }
    }

    var iconName: String {
        switch self {
        case .hrvVariability: "waveform.path.ecg"
        case .sleepConsistency: "moon.fill"
        case .activityLoad: "figure.run"
        }
    }

    var displayName: String {
        switch self {
        case .hrvVariability: String(localized: "HRV Variability")
        case .sleepConsistency: String(localized: "Sleep Consistency")
        case .activityLoad: String(localized: "Activity Load")
        }
    }
}
