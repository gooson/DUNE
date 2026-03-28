import Foundation

/// Sample of breathing disturbances during a single night of sleep.
struct BreathingDisturbanceSample: Sendable {
    /// Disturbances per hour of sleep.
    let value: Double
    /// Date of the sleep session.
    let date: Date
    /// Whether the value exceeds the elevated threshold.
    let isElevated: Bool
}

/// Aggregated analysis of breathing disturbances over a period.
struct BreathingDisturbanceAnalysis: Sendable {
    /// Nightly samples, most recent first.
    let samples: [BreathingDisturbanceSample]
    /// Average disturbances per hour over available data.
    let average: Double?
    /// Number of nights classified as elevated.
    let elevatedNightCount: Int
    /// Overall risk classification.
    let riskLevel: RiskLevel

    enum RiskLevel: String, Sendable, CaseIterable {
        case normal       // average < 5/hr
        case mild         // average 5-10/hr
        case elevated     // average 10-15/hr
        case significant  // average 15+/hr

        var displayName: String {
            switch self {
            case .normal: String(localized: "Normal")
            case .mild: String(localized: "Mild")
            case .elevated: String(localized: "Elevated")
            case .significant: String(localized: "Significant")
            }
        }
    }

    /// Classifies risk level from average disturbances per hour.
    static func classifyRisk(average: Double) -> RiskLevel {
        switch average {
        case ..<5: .normal
        case 5..<10: .mild
        case 10..<15: .elevated
        default: .significant
        }
    }
}
