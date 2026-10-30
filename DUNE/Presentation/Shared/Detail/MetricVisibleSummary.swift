import Foundation

/// Viewport statistics over accepted source rows, before chart aggregation and gap fill.
/// `statistics.count` counts the stated basis, never underlying HealthKit samples.
struct MetricVisibleSummary {
    enum Basis: Equatable {
        case hourlyAverages, dailyAverages, weeklyAverages, monthlyAverages
        case hourlyTotals, dailyTotals, weeklyTotals, monthlyTotals
        case recordedSleepDays, recordedWorkoutDays, measurements, nightlyRecords

        var displayName: String {
            switch self {
            case .hourlyAverages: String(localized: "Hourly averages")
            case .dailyAverages: String(localized: "Daily averages")
            case .weeklyAverages: String(localized: "Weekly averages")
            case .monthlyAverages: String(localized: "Monthly averages")
            case .hourlyTotals: String(localized: "Hourly totals")
            case .dailyTotals: String(localized: "Daily totals")
            case .weeklyTotals: String(localized: "Weekly totals")
            case .monthlyTotals: String(localized: "Monthly totals")
            case .recordedSleepDays: String(localized: "Recorded sleep days")
            case .recordedWorkoutDays: String(localized: "Recorded workout days")
            case .measurements: String(localized: "Measurements")
            case .nightlyRecords: String(localized: "Nightly records")
            }
        }

        static func resolve(category: HealthMetric.Category, period: TimePeriod) -> Self {
            switch category {
            case .hrv, .rhr, .heartRate:
                switch period {
                case .day: .hourlyAverages
                case .week, .month: .dailyAverages
                case .sixMonths: .weeklyAverages
                case .year: .monthlyAverages
                }
            case .steps:
                switch period {
                case .day: .hourlyTotals
                case .week, .month: .dailyTotals
                case .sixMonths: .weeklyTotals
                case .year: .monthlyTotals
                }
            case .sleep: .recordedSleepDays
            case .exercise: .recordedWorkoutDays
            case .breathingDisturbances: .nightlyRecords
            default: .measurements
            }
        }
    }

    let statistics: MetricSummary
    let basis: Basis
    let unit: String
    let isPartialHistory: Bool
    /// Only additive categories have totals. Comparison of averages lives in statistics.
    let total: Double?
    let previousTotal: Double?

    static func make(
        points: [ChartDataPoint], start: Date, duration: TimeInterval,
        coverage: DateInterval, referenceDate: Date, limitedStart: Date?,
        basis: Basis, unit: String, isAdditive: Bool
    ) -> Self? {
        guard duration.isFinite, duration > 0 else { return nil }
        let end = start.addingTimeInterval(duration)
        let priorStart = start.addingTimeInterval(-duration)
        let currentRequiredStart = max(start, limitedStart ?? start)
        let currentRequiredEnd = min(end, referenceDate)
        guard currentRequiredStart < currentRequiredEnd,
              coverage.start <= currentRequiredStart,
              coverage.end >= currentRequiredEnd else { return nil }

        let priorCovered = coverage.start <= priorStart && coverage.end >= start
            && (limitedStart.map { priorStart >= $0 } ?? true)
        let finite = points.filter { point in
            point.value.isFinite && point.date >= coverage.start && point.date < coverage.end
                && point.date <= referenceDate && (limitedStart.map { point.date >= $0 } ?? true)
        }
        let current = finite.filter { $0.date >= start && $0.date < end }
        let prior = priorCovered ? finite.filter { $0.date >= priorStart && $0.date < start } : []
        // Overflow is also invalid even when each input scalar is finite.
        let priorSum = prior.map(\.value).reduce(0, +)
        let usablePrior = priorSum.isFinite ? prior : []
        guard let stats = ScoreDetailHistory.summary(
            from: current + usablePrior, start: start, duration: duration
        ), stats.average.isFinite, stats.sum.isFinite,
           stats.min.isFinite, stats.max.isFinite else { return nil }
        return Self(
            statistics: stats, basis: basis, unit: unit,
            isPartialHistory: limitedStart.map { start < $0 } ?? false,
            total: isAdditive ? stats.sum : nil,
            previousTotal: isAdditive && !usablePrior.isEmpty ? priorSum : nil
        )
    }
}
