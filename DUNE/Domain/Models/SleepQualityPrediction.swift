import Foundation

/// Predicted sleep quality for tonight based on today's activity and recent patterns.
struct SleepQualityPrediction: Sendable, Hashable {
    let predictedScore: Int
    let confidence: Confidence
    let outlook: Outlook
    let factors: [PredictionFactor]
    let tips: [String]

    enum Confidence: String, Sendable, CaseIterable {
        case low
        case medium
        case high

        var displayName: String {
            switch self {
            case .low: String(localized: "Low Confidence")
            case .medium: String(localized: "Medium Confidence")
            case .high: String(localized: "High Confidence")
            }
        }
    }

    enum Outlook: String, Sendable, CaseIterable {
        case poor
        case fair
        case good
        case excellent

        var displayName: String {
            switch self {
            case .poor: String(localized: "Poor")
            case .fair: String(localized: "Fair")
            case .good: String(localized: "Good")
            case .excellent: String(localized: "Excellent")
            }
        }

        var guideMessage: String {
            switch self {
            case .poor: String(localized: "Sleep quality may be low tonight")
            case .fair: String(localized: "Moderate sleep expected")
            case .good: String(localized: "Good sleep conditions tonight")
            case .excellent: String(localized: "Great conditions for restful sleep")
            }
        }
    }

    struct PredictionFactor: Sendable, Hashable {
        let type: FactorType
        let impact: Impact
        let detail: String
    }

    enum FactorType: String, Sendable, Hashable {
        case recentSleepPattern
        case workoutEffect
        case hrvTrend
        case bedtimeConsistency
        case conditionLevel
    }

    enum Impact: String, Sendable, Hashable {
        case positive
        case neutral
        case negative
    }

    init(predictedScore: Int, confidence: Confidence, factors: [PredictionFactor] = [], tips: [String] = []) {
        self.predictedScore = max(0, min(100, predictedScore))
        self.confidence = confidence
        self.factors = factors
        self.tips = tips

        switch self.predictedScore {
        case 0...30: self.outlook = .poor
        case 31...55: self.outlook = .fair
        case 56...75: self.outlook = .good
        default: self.outlook = .excellent
        }
    }
}
