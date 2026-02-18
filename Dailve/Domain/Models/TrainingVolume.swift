import Foundation

// MARK: - Volume Period

/// Time period for training volume analysis.
enum VolumePeriod: String, CaseIterable, Sendable, Hashable {
    case week
    case month
    case threeMonths
    case sixMonths

    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .sixMonths: 180
        }
    }
}

// MARK: - Exercise Type Volume

/// Aggregated training volume for a specific exercise type within a period.
struct ExerciseTypeVolume: Identifiable, Sendable, Hashable {
    var id: String { typeKey }
    let typeKey: String
    let displayName: String
    let categoryRawValue: String
    let totalDuration: TimeInterval
    let totalCalories: Double
    let sessionCount: Int
    let totalDistance: Double?
    let totalVolume: Double?

    /// Duration fraction relative to total across all types.
    var durationFraction: Double = 0

    /// Calorie fraction relative to total across all types.
    var calorieFraction: Double = 0
}

// MARK: - Daily Volume Point

/// Single day's volume breakdown by exercise type for stacked bar charts.
struct DailyVolumePoint: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let segments: [Segment]

    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    struct Segment: Sendable, Hashable {
        let typeKey: String
        let duration: TimeInterval
    }
}

// MARK: - Volume Period Summary

/// Aggregated training volume summary for a specific time period.
struct VolumePeriodSummary: Sendable {
    let period: VolumePeriod
    let startDate: Date
    let endDate: Date
    let totalDuration: TimeInterval
    let totalCalories: Double
    let totalSessions: Int
    let activeDays: Int
    let exerciseTypes: [ExerciseTypeVolume]
    let dailyBreakdown: [DailyVolumePoint]
}

// MARK: - Period Comparison

/// Comparison between current and previous period volumes.
struct PeriodComparison: Sendable {
    let current: VolumePeriodSummary
    let previous: VolumePeriodSummary?

    var durationChange: Double? {
        guard let prev = previous, prev.totalDuration > 0 else { return nil }
        let change = ((current.totalDuration - prev.totalDuration) / prev.totalDuration) * 100
        return change.isFinite ? change : nil
    }

    var calorieChange: Double? {
        guard let prev = previous, prev.totalCalories > 0 else { return nil }
        let change = ((current.totalCalories - prev.totalCalories) / prev.totalCalories) * 100
        return change.isFinite ? change : nil
    }

    var sessionChange: Double? {
        guard let prev = previous, prev.totalSessions > 0 else { return nil }
        let change = Double(current.totalSessions - prev.totalSessions) / Double(prev.totalSessions) * 100
        return change.isFinite ? change : nil
    }

    var activeDaysChange: Double? {
        guard let prev = previous, prev.activeDays > 0 else { return nil }
        let change = Double(current.activeDays - prev.activeDays) / Double(prev.activeDays) * 100
        return change.isFinite ? change : nil
    }
}
