import SwiftUI

extension SleepDeficitAnalysis.DeficitLevel {
    var color: Color {
        switch self {
        case .good: DS.Color.scoreGood
        case .mild: DS.Color.scoreFair
        case .moderate: DS.Color.scoreTired
        case .severe: DS.Color.scoreWarning
        case .insufficient: DS.Color.textTertiary
        }
    }

    var label: String {
        switch self {
        case .good: String(localized: "Well Rested")
        case .mild: String(localized: "Slightly Short")
        case .moderate: String(localized: "Sleep Debt")
        case .severe: String(localized: "Severe Debt")
        case .insufficient: String(localized: "Collecting Data")
        }
    }
}

extension SleepDeficitAnalysis {
    /// Format weekly deficit as "Xh Ym" or "Ym".
    var formattedWeeklyDeficit: String {
        let hours = Int(weeklyDeficit) / 60
        let mins = Int(weeklyDeficit) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}
