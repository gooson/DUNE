import Foundation

/// Time period for metric detail chart display (D/W/M/6M/Y).
enum TimePeriod: String, CaseIterable, Sendable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"

    /// The date range for this period ending now, shifted by `offset` periods backward (negative) or forward.
    /// `offset = 0` is the current period, `offset = -1` is the previous period, etc.
    func dateRange(offset: Int = 0) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        // First compute current period end/start
        let baseEnd: Date = now
        let baseStart: Date
        switch self {
        case .day:
            baseStart = startOfToday
        case .week:
            baseStart = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        case .month:
            baseStart = calendar.date(byAdding: .month, value: -1, to: startOfToday) ?? startOfToday
        case .sixMonths:
            baseStart = calendar.date(byAdding: .month, value: -6, to: startOfToday) ?? startOfToday
        case .year:
            baseStart = calendar.date(byAdding: .year, value: -1, to: startOfToday) ?? startOfToday
        }

        guard offset != 0 else { return (baseStart, baseEnd) }

        // Shift both start and end by the offset
        let shiftedStart: Date
        let shiftedEnd: Date
        switch self {
        case .day:
            shiftedStart = calendar.date(byAdding: .day, value: offset, to: baseStart) ?? baseStart
            shiftedEnd = calendar.date(byAdding: .day, value: offset, to: baseEnd) ?? baseEnd
        case .week:
            shiftedStart = calendar.date(byAdding: .day, value: offset * 7, to: baseStart) ?? baseStart
            shiftedEnd = calendar.date(byAdding: .day, value: offset * 7, to: baseEnd) ?? baseEnd
        case .month:
            shiftedStart = calendar.date(byAdding: .month, value: offset, to: baseStart) ?? baseStart
            shiftedEnd = calendar.date(byAdding: .month, value: offset, to: baseEnd) ?? baseEnd
        case .sixMonths:
            shiftedStart = calendar.date(byAdding: .month, value: offset * 6, to: baseStart) ?? baseStart
            shiftedEnd = calendar.date(byAdding: .month, value: offset * 6, to: baseEnd) ?? baseEnd
        case .year:
            shiftedStart = calendar.date(byAdding: .year, value: offset, to: baseStart) ?? baseStart
            shiftedEnd = calendar.date(byAdding: .year, value: offset, to: baseEnd) ?? baseEnd
        }

        return (shiftedStart, shiftedEnd)
    }

    /// The date range for this period ending now (shorthand for offset 0).
    var dateRange: (start: Date, end: Date) {
        dateRange(offset: 0)
    }

    /// Calendar component for x-axis stride.
    var strideComponent: Calendar.Component {
        switch self {
        case .day: .hour
        case .week: .day
        case .month: .day
        case .sixMonths: .month
        case .year: .month
        }
    }

    /// Stride count for x-axis labels.
    var strideCount: Int {
        switch self {
        case .day: 4        // Every 4 hours
        case .week: 1       // Every day
        case .month: 7      // Every 7 days
        case .sixMonths: 1  // Every month
        case .year: 2       // Every 2 months
        }
    }

    /// Calendar component for data aggregation grouping.
    var aggregationUnit: Calendar.Component {
        switch self {
        case .day: .hour
        case .week: .day
        case .month: .day
        case .sixMonths: .weekOfYear
        case .year: .month
        }
    }

    /// Approximate number of expected data points for this period.
    var expectedPointCount: Int {
        switch self {
        case .day: 24
        case .week: 7
        case .month: 30
        case .sixMonths: 26   // ~26 weeks
        case .year: 12
        }
    }

    /// Visible time window in seconds for `chartXVisibleDomain(length:)`.
    var visibleDomainSeconds: TimeInterval {
        switch self {
        case .day:       24 * 3600                  // 24 hours
        case .week:      7 * 24 * 3600              // 7 days
        case .month:     31 * 24 * 3600             // ~31 days
        case .sixMonths: 183 * 24 * 3600            // ~6 months
        case .year:      365 * 24 * 3600            // ~1 year
        }
    }

    /// Number of periods of historical data to preload for scroll buffer.
    /// Keep small for large periods to avoid HealthKit query latency.
    var scrollBufferPeriods: Int {
        switch self {
        case .day: 7        // 7 days back
        case .week: 4       // 4 weeks back
        case .month: 3      // 3 months back
        case .sixMonths: 1  // 6 months back (= 1 year total)
        case .year: 1       // 1 year back (= 2 years total)
        }
    }

    // rangeLabel and visibleRangeLabel moved to Presentation/Shared/Extensions/TimePeriod+View.swift

    /// X-axis date format for chart labels.
    var axisLabelFormat: Date.FormatStyle {
        switch self {
        case .day:
            .dateTime.hour()
        case .week:
            .dateTime.weekday(.abbreviated)
        case .month:
            .dateTime.day()
        case .sixMonths:
            .dateTime.month(.abbreviated)
        case .year:
            .dateTime.month(.abbreviated)
        }
    }
}
