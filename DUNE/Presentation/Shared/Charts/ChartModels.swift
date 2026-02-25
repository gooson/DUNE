import Foundation

// MARK: - Base Data Point

/// Single value data point for line/bar/area charts.
struct ChartDataPoint: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let value: Double
}

// MARK: - Range Data Point

/// Min-max range data point for RHR capsule bar charts.
struct RangeDataPoint: Identifiable, Sendable {
    var id: Date { date }
    let date: Date
    let min: Double
    let max: Double
    let average: Double
}

// MARK: - Stacked Data Point

/// Multi-segment stacked data point for sleep stage charts.
struct StackedDataPoint: Identifiable, Sendable {
    let id: String
    let date: Date
    let segments: [Segment]

    var total: Double {
        segments.reduce(0) { $0 + $1.value }
    }

    struct Segment: Sendable {
        let category: String
        let value: Double
    }
}

// MARK: - Metric Summary

/// Summary statistics for a metric over a time period.
struct MetricSummary: Sendable {
    let average: Double
    let min: Double
    let max: Double
    let sum: Double
    let count: Int
    let previousPeriodAverage: Double?

    /// Change percentage compared to previous period.
    var changePercentage: Double? {
        guard let previous = previousPeriodAverage, previous > 0 else { return nil }
        return ((average - previous) / previous) * 100
    }
}

// MARK: - Exercise Totals

/// Aggregate exercise stats for a time period.
struct ExerciseTotals: Sendable {
    let workoutCount: Int
    let totalDuration: TimeInterval
    let totalCalories: Double?
    let totalDistanceMeters: Double?
}

// MARK: - Highlight

/// Notable data point within a time period (e.g. weekly high/low).
struct Highlight: Identifiable, Sendable {
    var id: String { "\(type.rawValue)-\(date.timeIntervalSince1970)" }
    let type: HighlightType
    let value: Double
    let date: Date
    let label: String

    enum HighlightType: String, Sendable {
        case high
        case low
        case trend
    }
}
