import Foundation
import SwiftData

/// Hourly score snapshot persisted to SwiftData + CloudKit.
/// Stores condition, wellness, and readiness scores at hour-level granularity.
/// All score fields are Optional for CloudKit compatibility.
@Model
final class HourlyScoreSnapshot {
    /// Hour-truncated date (e.g. 2026-03-13T14:00:00Z). Serves as logical primary key.
    var date: Date = Date()

    /// Condition score at this hour (0-100)
    var conditionScore: Double?

    /// Wellness score at this hour (0-100)
    var wellnessScore: Double?

    /// Training readiness score at this hour (0-100)
    var readinessScore: Double?

    /// HRV value used for this calculation (ms)
    var hrvValue: Double?

    /// RHR value used for this calculation (bpm)
    var rhrValue: Double?

    /// Sleep score component used (0-100)
    var sleepScore: Double?

    /// When this snapshot was created/last updated
    var createdAt: Date = Date()

    init(
        date: Date,
        conditionScore: Double? = nil,
        wellnessScore: Double? = nil,
        readinessScore: Double? = nil,
        hrvValue: Double? = nil,
        rhrValue: Double? = nil,
        sleepScore: Double? = nil
    ) {
        self.date = date
        self.conditionScore = conditionScore
        self.wellnessScore = wellnessScore
        self.readinessScore = readinessScore
        self.hrvValue = hrvValue
        self.rhrValue = rhrValue
        self.sleepScore = sleepScore
        self.createdAt = Date()
    }

    /// Truncate a date to the start of its hour
    static func hourTruncated(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .hour, for: date)?.start ?? date
    }
}
