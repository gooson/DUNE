import Foundation

/// Fixed-duration history pages and raw-point summaries shared by score detail screens.
enum ScoreDetailHistory {
    static func window(
        for period: TimePeriod,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> (latestStart: Date, domain: ClosedRange<Date>) {
        let end = period == .day
            ? referenceDate
            : period.scrollDomainUpperBound(referenceDate: referenceDate, calendar: calendar)
        let latestStart = end.addingTimeInterval(-period.visibleDomainSeconds)
        let lowerBound = latestStart.addingTimeInterval(
            -Double(period.scrollBufferPeriods) * period.visibleDomainSeconds
        )
        return (latestStart, lowerBound...end)
    }

    static func summary(
        from points: [ChartDataPoint], start: Date, duration: TimeInterval
    ) -> MetricSummary? {
        guard duration.isFinite, duration > 0 else { return nil }
        let end = start.addingTimeInterval(duration)
        let previousStart = start.addingTimeInterval(-duration)
        let values = points.filter { $0.date >= start && $0.date < end }.map(\.value)
        let previous = points.filter { $0.date >= previousStart && $0.date < start }.map(\.value)
        return HealthDataAggregator.computeSummary(
            from: values, previousPeriodValues: previous.isEmpty ? nil : previous
        )
    }
}
