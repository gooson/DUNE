import Foundation

/// 30-day rolling cumulative stress indicator.
/// Aggregates HRV variability, sleep consistency, and training load
/// into a single long-term stress metric (0-100).
struct CumulativeStressScore: Sendable, Identifiable, Hashable {
    let id: UUID
    /// 0 (minimal stress) to 100 (maximal stress).
    let score: Int
    let level: Level
    let contributions: [Contribution]
    let trend: TrendDirection
    let date: Date
    let windowDays: Int

    init(
        score: Int,
        level: Level,
        contributions: [Contribution],
        trend: TrendDirection,
        date: Date = .now,
        windowDays: Int = 30
    ) {
        self.id = UUID()
        self.score = score
        self.level = level
        self.contributions = contributions
        self.trend = trend
        self.date = date
        self.windowDays = windowDays
    }

    enum Level: String, Sendable, CaseIterable, Hashable {
        case low
        case moderate
        case elevated
        case high

        var displayName: String {
            switch self {
            case .low: String(localized: "Low")
            case .moderate: String(localized: "Moderate")
            case .elevated: String(localized: "Elevated")
            case .high: String(localized: "High")
            }
        }

        static func from(score: Int) -> Level {
            switch score {
            case 0..<30: .low
            case 30..<55: .moderate
            case 55..<75: .elevated
            default: .high
            }
        }
    }

    struct Contribution: Sendable, Identifiable, Hashable {
        let id: UUID
        let factor: Factor
        let rawScore: Double
        let weight: Double
        let detail: String

        init(factor: Factor, rawScore: Double, weight: Double, detail: String) {
            self.id = UUID()
            self.factor = factor
            self.rawScore = rawScore
            self.weight = weight
            self.detail = detail
        }

        enum Factor: String, Sendable, Hashable {
            case hrvVariability
            case sleepConsistency
            case activityLoad
        }
    }
}
