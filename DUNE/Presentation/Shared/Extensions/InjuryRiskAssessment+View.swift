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

extension InjuryRiskAssessment.Level {
    var color: Color {
        switch self {
        case .low: DS.Color.positive
        case .moderate: DS.Color.caution
        case .high: .orange
        case .critical: DS.Color.negative
        }
    }

    var iconName: String {
        switch self {
        case .low: "checkmark.shield"
        case .moderate: "exclamationmark.shield"
        case .high: "exclamationmark.triangle"
        case .critical: "xmark.shield"
        }
    }

    var recommendations: [String] {
        switch self {
        case .low:
            [
                String(localized: "Continue your current training plan"),
                String(localized: "Maintain good sleep and recovery habits"),
            ]
        case .moderate:
            [
                String(localized: "Allow adequate rest between sessions"),
                String(localized: "Include stretching and mobility work"),
                String(localized: "Monitor any muscle soreness closely"),
            ]
        case .high:
            [
                String(localized: "Consider reducing today's training intensity"),
                String(localized: "Focus on recovery: sleep, nutrition, hydration"),
                String(localized: "Avoid training muscle groups with high fatigue"),
                String(localized: "Light activity like walking is still beneficial"),
            ]
        case .critical:
            [
                String(localized: "Rest is strongly recommended today"),
                String(localized: "Prioritize sleep and recovery"),
                String(localized: "Consult a professional if pain persists"),
                String(localized: "Return to training gradually when recovered"),
            ]
        }
    }
}
