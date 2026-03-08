import SwiftUI

extension SleepQualityPrediction.FactorType {
    var displayName: String {
        switch self {
        case .recentSleepPattern: String(localized: "Recent Sleep Pattern")
        case .workoutEffect: String(localized: "Workout Effect")
        case .hrvTrend: String(localized: "HRV Trend")
        case .bedtimeConsistency: String(localized: "Bedtime Consistency")
        case .conditionLevel: String(localized: "Condition Level")
        }
    }

    var iconName: String {
        switch self {
        case .recentSleepPattern: "bed.double"
        case .workoutEffect: "figure.run"
        case .hrvTrend: "heart.text.square"
        case .bedtimeConsistency: "clock"
        case .conditionLevel: "gauge.with.dots.needle.33percent"
        }
    }
}

extension SleepQualityPrediction.Impact {
    var iconName: String {
        switch self {
        case .positive: "arrow.up.circle.fill"
        case .neutral: "minus.circle.fill"
        case .negative: "arrow.down.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .positive: DS.Color.positive
        case .neutral: DS.Color.textSecondary
        case .negative: DS.Color.negative
        }
    }
}
