import Foundation

/// Correlation analysis between outdoor weather conditions and sleep quality.
struct SleepEnvironmentAnalysis: Sendable {
    /// Number of day pairs analyzed (weather + sleep).
    let dataPointCount: Int

    /// Confidence based on sample size.
    let confidence: Confidence

    /// Temperature impact on sleep quality.
    let temperatureInsight: EnvironmentInsight?

    /// Humidity impact on sleep quality.
    let humidityInsight: EnvironmentInsight?

    /// Daily data points for scatter visualization.
    let dailyPairs: [DayPair]

    struct EnvironmentInsight: Sendable {
        /// Average sleep score in optimal conditions.
        let bestSleepAvgScore: Double
        /// Average sleep score in worst conditions.
        let worstSleepAvgScore: Double
        /// Optimal range (e.g., 18-22°C).
        let optimalRange: ClosedRange<Double>
        /// Human-readable insight message.
        let message: String
    }

    struct DayPair: Sendable, Identifiable {
        var id: Date { date }
        let date: Date
        let sleepScore: Int
        let temperature: Double
        let humidity: Double
    }

    enum Confidence: String, Sendable {
        case low      // < 14 pairs
        case medium   // 14-29 pairs
        case high     // >= 30 pairs

        var displayName: String {
            switch self {
            case .low: String(localized: "Low")
            case .medium: String(localized: "Medium")
            case .high: String(localized: "High")
            }
        }
    }
}
