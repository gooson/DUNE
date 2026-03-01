import Foundation

/// Shared utility for building highlights from chart data.
/// Eliminates duplication between MetricDetailViewModel and ConditionScoreDetailViewModel.
enum HighlightBuilder {

    private static let trendSignificanceThreshold = 3.0 // percent

    /// Builds standard highlights (highest, lowest, trend) from chart data points.
    static func buildHighlights(from currentValues: [ChartDataPoint]) -> [Highlight] {
        guard !currentValues.isEmpty else { return [] }

        var result: [Highlight] = []

        if let maxPoint = currentValues.max(by: { $0.value < $1.value }) {
            result.append(Highlight(
                type: .high,
                value: maxPoint.value,
                date: maxPoint.date,
                label: String(localized: "Highest")
            ))
        }

        if let minPoint = currentValues.min(by: { $0.value < $1.value }) {
            result.append(Highlight(
                type: .low,
                value: minPoint.value,
                date: minPoint.date,
                label: String(localized: "Lowest")
            ))
        }

        if let trend = computeTrend(from: currentValues) {
            result.append(trend)
        }

        return result
    }

    /// Builds highlights with custom labels for highest/lowest (e.g. "Best day" / "Lowest day").
    static func buildHighlights(
        from currentValues: [ChartDataPoint],
        highLabel: String,
        lowLabel: String
    ) -> [Highlight] {
        guard !currentValues.isEmpty else { return [] }

        var result: [Highlight] = []

        if let maxPoint = currentValues.max(by: { $0.value < $1.value }) {
            result.append(Highlight(
                type: .high,
                value: maxPoint.value,
                date: maxPoint.date,
                label: highLabel
            ))
        }

        if let minPoint = currentValues.min(by: { $0.value < $1.value }) {
            result.append(Highlight(
                type: .low,
                value: minPoint.value,
                date: minPoint.date,
                label: lowLabel
            ))
        }

        if let trend = computeTrend(from: currentValues) {
            result.append(trend)
        }

        return result
    }

    /// Computes trend direction by comparing first-half vs second-half averages.
    /// Returns nil if fewer than 4 data points or change is below threshold.
    static func computeTrend(from values: [ChartDataPoint]) -> Highlight? {
        guard values.count >= 4 else { return nil }

        let mid = values.count / 2
        let firstHalf = values[..<mid].map(\.value)
        let secondHalf = values[mid...].map(\.value)

        guard firstHalf.count > 0, secondHalf.count > 0 else { return nil }

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

        guard firstAvg > 0 else { return nil }

        let changePercent = ((secondAvg - firstAvg) / firstAvg) * 100
        guard !changePercent.isNaN, !changePercent.isInfinite else { return nil }
        guard abs(changePercent) >= trendSignificanceThreshold else { return nil }

        let direction = changePercent > 0 ? String(localized: "Trending up") : String(localized: "Trending down")
        return Highlight(
            type: .trend,
            value: changePercent,
            date: Date(),
            label: direction
        )
    }
}
