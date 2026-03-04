import Foundation

/// Result of sleep deficit analysis comparing actual sleep against personal average.
struct SleepDeficitAnalysis: Sendable {
    /// 14-day rolling average sleep duration in minutes (excluding zero-data days).
    let shortTermAverage: Double

    /// 90-day rolling average sleep duration in minutes (nil if < 7 data points).
    let longTermAverage: Double?

    /// Cumulative sleep deficit over last 7 days in minutes (positive = deficit).
    let weeklyDeficit: Double

    /// Per-day deficit breakdown for last 7 days.
    let dailyDeficits: [DailyDeficit]

    /// Severity classification based on weekly deficit.
    let level: DeficitLevel

    /// Number of days with actual sleep data in the 14-day window.
    let dataPointCount: Int

    struct DailyDeficit: Sendable {
        let date: Date
        let actualMinutes: Double
        /// Positive = slept less than average; 0 = met or exceeded average.
        let deficitMinutes: Double
    }

    enum DeficitLevel: String, Sendable {
        case good          // < 120 min (2h)
        case mild          // 120-300 min (2-5h)
        case moderate      // 300-600 min (5-10h)
        case severe        // > 600 min (10h)
        case insufficient  // < 3 data points in 14-day window
    }
}
