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

        // First compute current period end/start
        let baseEnd: Date
        let baseStart: Date
        switch self {
        case .day:
            baseEnd = now
            baseStart = calendar.startOfDay(for: now)
        case .week:
            baseEnd = now
            baseStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
        case .month:
            baseEnd = now
            baseStart = calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: now))!
        case .sixMonths:
            baseEnd = now
            baseStart = calendar.date(byAdding: .month, value: -6, to: calendar.startOfDay(for: now))!
        case .year:
            baseEnd = now
            baseStart = calendar.date(byAdding: .year, value: -1, to: calendar.startOfDay(for: now))!
        }

        guard offset != 0 else { return (baseStart, baseEnd) }

        // Shift both start and end by the offset
        let shiftedStart: Date
        let shiftedEnd: Date
        switch self {
        case .day:
            shiftedStart = calendar.date(byAdding: .day, value: offset, to: baseStart)!
            shiftedEnd = calendar.date(byAdding: .day, value: offset, to: baseEnd)!
        case .week:
            shiftedStart = calendar.date(byAdding: .day, value: offset * 7, to: baseStart)!
            shiftedEnd = calendar.date(byAdding: .day, value: offset * 7, to: baseEnd)!
        case .month:
            shiftedStart = calendar.date(byAdding: .month, value: offset, to: baseStart)!
            shiftedEnd = calendar.date(byAdding: .month, value: offset, to: baseEnd)!
        case .sixMonths:
            shiftedStart = calendar.date(byAdding: .month, value: offset * 6, to: baseStart)!
            shiftedEnd = calendar.date(byAdding: .month, value: offset * 6, to: baseEnd)!
        case .year:
            shiftedStart = calendar.date(byAdding: .year, value: offset, to: baseStart)!
            shiftedEnd = calendar.date(byAdding: .year, value: offset, to: baseEnd)!
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

    /// Formatted label for the given offset's date range.
    func rangeLabel(offset: Int) -> String {
        guard offset != 0 else { return "" }
        let range = dateRange(offset: offset)
        let formatter = DateFormatter()
        switch self {
        case .day:
            formatter.dateFormat = "M/d (E)"
            return formatter.string(from: range.start)
        case .week:
            formatter.dateFormat = "M/d"
            let start = formatter.string(from: range.start)
            let end = formatter.string(from: range.end)
            return "\(start) – \(end)"
        case .month:
            formatter.dateFormat = "yyyy.M"
            return formatter.string(from: range.start)
        case .sixMonths:
            formatter.dateFormat = "yyyy.M"
            let start = formatter.string(from: range.start)
            let end = formatter.string(from: range.end)
            return "\(start) – \(end)"
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: range.start)
        }
    }

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
