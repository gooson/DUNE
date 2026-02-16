import Foundation

/// Aggregates raw health data points into period-based summaries.
/// Pure domain logic — no HealthKit or UI dependencies.
enum HealthDataAggregator {

    // MARK: - Chart Data Aggregation

    /// Groups raw data points by the given calendar component and computes averages.
    static func aggregateByAverage(
        _ data: [ChartDataPoint],
        unit: Calendar.Component,
        calendar: Calendar = .current
    ) -> [ChartDataPoint] {
        guard !data.isEmpty else { return [] }

        let grouped = groupByUnit(data, unit: unit, calendar: calendar)
        return grouped
            .map { date, values in
                let count = values.count
                guard count > 0 else { return ChartDataPoint(date: date, value: 0) }
                let avg = values.reduce(0, +) / Double(count)
                return ChartDataPoint(date: date, value: avg)
            }
            .sorted { $0.date < $1.date }
    }

    /// Groups raw data points by the given calendar component and computes sums.
    static func aggregateBySum(
        _ data: [ChartDataPoint],
        unit: Calendar.Component,
        calendar: Calendar = .current
    ) -> [ChartDataPoint] {
        guard !data.isEmpty else { return [] }

        let grouped = groupByUnit(data, unit: unit, calendar: calendar)
        return grouped
            .map { date, values in
                ChartDataPoint(date: date, value: values.reduce(0, +))
            }
            .sorted { $0.date < $1.date }
    }

    /// Aggregates range data (min/max/avg) by the given calendar component.
    static func aggregateRangeData(
        _ data: [RangeDataPoint],
        unit: Calendar.Component,
        calendar: Calendar = .current
    ) -> [RangeDataPoint] {
        guard !data.isEmpty else { return [] }

        var grouped: [Date: [RangeDataPoint]] = [:]
        for point in data {
            let key = dateKey(for: point.date, unit: unit, calendar: calendar)
            grouped[key, default: []].append(point)
        }

        return grouped
            .map { date, points in
                let minVal = points.map(\.min).min() ?? 0
                let maxVal = points.map(\.max).max() ?? 0
                let avgVal = points.map(\.average).reduce(0, +) / Double(points.count)
                return RangeDataPoint(date: date, min: minVal, max: maxVal, average: avgVal)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Summary

    /// Computes statistical summary from an array of values.
    static func computeSummary(
        from values: [Double],
        previousPeriodValues: [Double]? = nil
    ) -> MetricSummary? {
        guard !values.isEmpty else { return nil }

        let avg = values.reduce(0, +) / Double(values.count)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        let sum = values.reduce(0, +)

        var prevAvg: Double?
        if let prev = previousPeriodValues, !prev.isEmpty {
            prevAvg = prev.reduce(0, +) / Double(prev.count)
        }

        return MetricSummary(
            average: avg,
            min: minVal,
            max: maxVal,
            sum: sum,
            count: values.count,
            previousPeriodAverage: prevAvg
        )
    }

    // MARK: - Previous Period

    /// Computes the previous period date range matching the given period's duration.
    static func previousPeriodRange(for period: TimePeriod, offset: Int = 0) -> (start: Date, end: Date) {
        let current = period.dateRange(offset: offset)
        let calendar = Calendar.current
        let duration = current.end.timeIntervalSince(current.start)
        let prevEnd = current.start
        let prevStart = calendar.date(byAdding: .second, value: -Int(duration), to: prevEnd) ?? prevEnd
        return (prevStart, prevEnd)
    }

    // MARK: - Interval for TimePeriod

    /// Returns the DateComponents interval for HKStatisticsCollection queries.
    static func intervalComponents(for period: TimePeriod) -> DateComponents {
        switch period {
        case .day:       DateComponents(hour: 1)
        case .week:      DateComponents(day: 1)
        case .month:     DateComponents(day: 1)
        case .sixMonths: DateComponents(weekOfYear: 1)
        case .year:      DateComponents(month: 1)
        }
    }

    // MARK: - Date Gap Filling

    /// Fills date gaps in chart data so every expected date slot has a data point.
    /// Missing dates get value 0. Ensures charts render a continuous date axis
    /// like Apple Health, even when no data exists for some dates.
    static func fillDateGaps(
        _ data: [ChartDataPoint],
        period: TimePeriod,
        start: Date,
        end: Date,
        calendar: Calendar = .current
    ) -> [ChartDataPoint] {
        let unit = period.aggregationUnit

        // Build a set of existing date keys for fast lookup
        var existing: [Date: Double] = [:]
        for point in data {
            let key = dateKey(for: point.date, unit: unit, calendar: calendar)
            existing[key] = point.value
        }

        // Generate all expected date slots from start to end
        var result: [ChartDataPoint] = []
        var current = dateKey(for: start, unit: unit, calendar: calendar)
        let endKey = dateKey(for: end, unit: unit, calendar: calendar)

        let stepComponent: Calendar.Component
        let stepValue: Int
        switch unit {
        case .hour:
            stepComponent = .hour; stepValue = 1
        case .day:
            stepComponent = .day; stepValue = 1
        case .weekOfYear:
            stepComponent = .weekOfYear; stepValue = 1
        case .month:
            stepComponent = .month; stepValue = 1
        default:
            stepComponent = .day; stepValue = 1
        }

        while current <= endKey {
            let value = existing[current] ?? 0
            result.append(ChartDataPoint(date: current, value: value))
            guard let next = calendar.date(byAdding: stepComponent, value: stepValue, to: current) else { break }
            current = next
        }

        return result
    }

    // MARK: - Private

    private static func groupByUnit(
        _ data: [ChartDataPoint],
        unit: Calendar.Component,
        calendar: Calendar
    ) -> [Date: [Double]] {
        var grouped: [Date: [Double]] = [:]
        for point in data {
            let key = dateKey(for: point.date, unit: unit, calendar: calendar)
            grouped[key, default: []].append(point.value)
        }
        return grouped
    }

    private static func dateKey(
        for date: Date,
        unit: Calendar.Component,
        calendar: Calendar
    ) -> Date {
        if unit == .weekOfYear {
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return calendar.date(from: components) ?? date
        }
        return calendar.dateInterval(of: unit, for: date)?.start ?? date
    }
}
