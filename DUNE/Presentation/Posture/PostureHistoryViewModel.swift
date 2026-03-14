import Foundation
import Observation

// MARK: - ViewModel

@Observable
@MainActor
final class PostureHistoryViewModel {

    // MARK: - State

    var chartData: [ChartDataPoint] = []
    var selectedMetricFilter: PostureMetricType?
    var comparisonSelection: Set<UUID> = []

    // MARK: - Statistics

    private(set) var averageScore: Double = 0
    private(set) var bestScore: Int = 0
    private(set) var worstScore: Int = 0
    private(set) var totalMeasurements: Int = 0
    private(set) var changePercentage: Double?

    // MARK: - Load

    func loadHistory(from records: [PostureAssessmentRecord]) {
        totalMeasurements = records.count
        guard !records.isEmpty else {
            chartData = []
            averageScore = 0
            bestScore = 0
            worstScore = 0
            changePercentage = nil
            return
        }

        let sorted = records.sorted { $0.date < $1.date }

        // Chart data
        if let filter = selectedMetricFilter {
            chartData = metricTrendData(for: filter, records: sorted)
        } else {
            chartData = sorted.map { record in
                ChartDataPoint(date: record.date, value: Double(record.overallScore))
            }
        }

        // Statistics
        let scores = sorted.map(\.overallScore)
        averageScore = Double(scores.reduce(0, +)) / Double(scores.count)
        bestScore = scores.max() ?? 0
        worstScore = scores.min() ?? 0

        // Change percentage: latest vs first
        if scores.count >= 2, let first = scores.first, let last = scores.last, first > 0 {
            let change = (Double(last) - Double(first)) / Double(first) * 100
            changePercentage = change.isFinite ? change : nil
        } else {
            changePercentage = nil
        }
    }

    // MARK: - Metric Trend

    func metricTrendData(for metricType: PostureMetricType, records: [PostureAssessmentRecord]) -> [ChartDataPoint] {
        records.compactMap { record in
            let allMetrics = record.allMetrics
            guard let metric = allMetrics.first(where: { $0.type == metricType }),
                  metric.status != .unmeasurable else { return nil }
            return ChartDataPoint(date: record.date, value: Double(metric.score))
        }
    }

    // MARK: - Comparison

    func comparisonDelta(
        older: PostureAssessmentRecord,
        newer: PostureAssessmentRecord
    ) -> [MetricDelta] {
        let olderMetrics = Dictionary(
            older.allMetrics.map { ($0.type, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let newerMetrics = Dictionary(
            newer.allMetrics.map { ($0.type, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let allTypes = Set(olderMetrics.keys).union(newerMetrics.keys)
        return allTypes.sorted(by: { $0.rawValue < $1.rawValue }).map { type in
            let oldScore = olderMetrics[type]?.score
            let newScore = newerMetrics[type]?.score
            let oldValue = olderMetrics[type]?.value
            let newValue = newerMetrics[type]?.value
            let unit = olderMetrics[type]?.unit ?? newerMetrics[type]?.unit ?? .degrees
            return MetricDelta(
                type: type,
                oldScore: oldScore,
                newScore: newScore,
                oldValue: oldValue,
                newValue: newValue,
                unit: unit
            )
        }
    }

    // MARK: - Selection

    func toggleComparison(_ id: UUID) {
        if comparisonSelection.contains(id) {
            comparisonSelection.remove(id)
        } else if comparisonSelection.count < 2 {
            comparisonSelection.insert(id)
        }
    }

    var canCompare: Bool {
        comparisonSelection.count == 2
    }
}

// MARK: - MetricDelta

struct MetricDelta: Identifiable, Sendable {
    var id: PostureMetricType { type }
    let type: PostureMetricType
    let oldScore: Int?
    let newScore: Int?
    let oldValue: Double?
    let newValue: Double?
    let unit: PostureMetricUnit

    var scoreDelta: Int? {
        guard let old = oldScore, let new = newScore else { return nil }
        return new - old
    }

    var isImproved: Bool? {
        guard let delta = scoreDelta else { return nil }
        return delta > 0
    }
}
