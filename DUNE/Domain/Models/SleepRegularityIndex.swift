import Foundation

/// Sleep Regularity Index — measures consistency of bedtime and wake time.
/// Score 0-100 where 100 = perfectly regular schedule.
struct SleepRegularityIndex: Sendable {
    /// Overall regularity score (0-100).
    let score: Int

    /// Standard deviation of bedtime in minutes.
    let bedtimeStdDevMinutes: Double

    /// Standard deviation of wake time in minutes.
    let wakeTimeStdDevMinutes: Double

    /// Average bedtime (hour/minute components).
    let averageBedtime: DateComponents

    /// Average wake time (hour/minute components).
    let averageWakeTime: DateComponents

    /// Number of nights analyzed.
    let dataPointCount: Int

    /// Confidence based on sample size.
    let confidence: Confidence

    enum Confidence: String, Sendable {
        case low      // < 7 nights
        case medium   // 7-13 nights
        case high     // >= 14 nights

        var displayName: String {
            switch self {
            case .low: String(localized: "Low")
            case .medium: String(localized: "Medium")
            case .high: String(localized: "High")
            }
        }
    }
}
