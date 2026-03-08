import SwiftUI

extension InjuryRiskAssessment.FactorType {
    var displayName: String {
        switch self {
        case .muscleFatigue: String(localized: "Muscle Fatigue")
        case .consecutiveTraining: String(localized: "Consecutive Training")
        case .volumeSpike: String(localized: "Volume Spike")
        case .sleepDeficit: String(localized: "Sleep Deficit")
        case .activeInjury: String(localized: "Active Injury")
        case .lowRecovery: String(localized: "Low Recovery")
        }
    }

    var iconName: String {
        switch self {
        case .muscleFatigue: "figure.walk"
        case .consecutiveTraining: "calendar.badge.exclamationmark"
        case .volumeSpike: "chart.line.uptrend.xyaxis"
        case .sleepDeficit: "moon.zzz"
        case .activeInjury: "bandage"
        case .lowRecovery: "battery.25percent"
        }
    }
}
