import Foundation

/// Time period for metric detail chart display (D/W/M/6M/Y).
enum TimePeriod: String, CaseIterable, Sendable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"

    /// The date range for this period ending now.
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let end = Date()
        let start: Date
        switch self {
        case .day:
            start = calendar.startOfDay(for: end)
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: end))!
        case .month:
            start = calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: end))!
        case .sixMonths:
            start = calendar.date(byAdding: .month, value: -6, to: calendar.startOfDay(for: end))!
        case .year:
            start = calendar.date(byAdding: .year, value: -1, to: calendar.startOfDay(for: end))!
        }
        return (start, end)
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
