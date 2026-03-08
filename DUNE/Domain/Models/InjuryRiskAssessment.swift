import Foundation

/// Injury risk assessment computed from fatigue, training patterns, sleep, and injury history.
struct InjuryRiskAssessment: Sendable, Hashable {
    let score: Int
    let level: Level
    let factors: [RiskFactor]
    let date: Date

    enum Level: String, Sendable, CaseIterable {
        case low
        case moderate
        case high
        case critical

        var displayName: String {
            switch self {
            case .low: String(localized: "Low Risk")
            case .moderate: String(localized: "Moderate Risk")
            case .high: String(localized: "High Risk")
            case .critical: String(localized: "Critical Risk")
            }
        }

        var guideMessage: String {
            switch self {
            case .low: String(localized: "Training safely — keep it up")
            case .moderate: String(localized: "Watch your recovery between sessions")
            case .high: String(localized: "Consider reducing intensity today")
            case .critical: String(localized: "Rest recommended — high injury risk")
            }
        }
    }

    struct RiskFactor: Sendable, Hashable {
        let type: FactorType
        let contribution: Int
        let detail: String
    }

    enum FactorType: String, Sendable, Hashable {
        case muscleFatigue
        case consecutiveTraining
        case volumeSpike
        case sleepDeficit
        case activeInjury
        case lowRecovery
    }

    init(score: Int, factors: [RiskFactor] = [], date: Date = Date()) {
        self.score = max(0, min(100, score))
        self.factors = factors
        self.date = date

        switch self.score {
        case 0...25: self.level = .low
        case 26...50: self.level = .moderate
        case 51...75: self.level = .high
        default: self.level = .critical
        }
    }
}
