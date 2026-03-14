import Foundation
import Testing

@testable import DUNE

@Suite("PostureHistoryViewModel")
@MainActor
struct PostureHistoryViewModelTests {

    // MARK: - Helpers

    private func makeRecord(
        date: Date = Date(),
        overallScore: Int = 75,
        frontMetrics: [PostureMetricResult] = [],
        sideMetrics: [PostureMetricResult] = []
    ) -> PostureAssessmentRecord {
        PostureAssessmentRecord(
            date: date,
            overallScore: overallScore,
            frontMetrics: frontMetrics,
            sideMetrics: sideMetrics
        )
    }

    private func makeMetric(
        type: PostureMetricType,
        value: Double = 10.0,
        score: Int = 80,
        status: PostureStatus = .normal,
        unit: PostureMetricUnit = .degrees
    ) -> PostureMetricResult {
        PostureMetricResult(type: type, value: value, unit: unit, status: status, score: score)
    }

    // MARK: - loadHistory

    @Test("loadHistory with empty records resets state")
    func loadHistoryEmpty() {
        let vm = PostureHistoryViewModel()

        vm.loadHistory(from: [])

        #expect(vm.chartData.isEmpty)
        #expect(vm.totalMeasurements == 0)
        #expect(vm.averageScore == 0)
        #expect(vm.bestScore == 0)
        #expect(vm.worstScore == 0)
        #expect(vm.changePercentage == nil)
    }

    @Test("loadHistory computes statistics correctly")
    func loadHistoryStatistics() {
        let vm = PostureHistoryViewModel()
        let now = Date()
        let records = [
            makeRecord(date: now.addingTimeInterval(-86400 * 2), overallScore: 60),
            makeRecord(date: now.addingTimeInterval(-86400), overallScore: 80),
            makeRecord(date: now, overallScore: 90),
        ]

        vm.loadHistory(from: records)

        #expect(vm.totalMeasurements == 3)
        #expect(vm.bestScore == 90)
        #expect(vm.worstScore == 60)
        // Average: (60+80+90)/3 = 76.67
        #expect(Int(vm.averageScore.rounded()) == 77)
        // Change: (90-60)/60*100 = 50%
        #expect(vm.changePercentage != nil)
        if let change = vm.changePercentage {
            #expect(abs(change - 50.0) < 0.1)
        }
    }

    @Test("loadHistory generates chart data sorted by date")
    func loadHistoryChartData() {
        let vm = PostureHistoryViewModel()
        let now = Date()
        let records = [
            makeRecord(date: now.addingTimeInterval(-86400), overallScore: 70),
            makeRecord(date: now, overallScore: 85),
        ]

        vm.loadHistory(from: records)

        #expect(vm.chartData.count == 2)
        #expect(vm.chartData[0].value == 70)
        #expect(vm.chartData[1].value == 85)
    }

    @Test("loadHistory with single record has nil changePercentage")
    func loadHistorySingleRecord() {
        let vm = PostureHistoryViewModel()
        let records = [makeRecord(overallScore: 75)]

        vm.loadHistory(from: records)

        #expect(vm.totalMeasurements == 1)
        #expect(vm.changePercentage == nil)
    }

    // MARK: - Metric Trend

    @Test("metricTrendData filters by metric type")
    func metricTrendFilter() {
        let vm = PostureHistoryViewModel()
        let now = Date()
        let records = [
            makeRecord(
                date: now.addingTimeInterval(-86400),
                overallScore: 70,
                frontMetrics: [makeMetric(type: .shoulderAsymmetry, score: 65)]
            ),
            makeRecord(
                date: now,
                overallScore: 80,
                frontMetrics: [makeMetric(type: .shoulderAsymmetry, score: 85)],
                sideMetrics: [makeMetric(type: .forwardHead, score: 70)]
            ),
        ]

        let trend = vm.metricTrendData(for: .shoulderAsymmetry, records: records)

        #expect(trend.count == 2)
        #expect(trend[0].value == 65)
        #expect(trend[1].value == 85)
    }

    @Test("metricTrendData excludes unmeasurable results")
    func metricTrendExcludesUnmeasurable() {
        let vm = PostureHistoryViewModel()
        let records = [
            makeRecord(
                date: Date(),
                frontMetrics: [makeMetric(type: .shoulderAsymmetry, score: 0, status: .unmeasurable)]
            ),
        ]

        let trend = vm.metricTrendData(for: .shoulderAsymmetry, records: records)

        #expect(trend.isEmpty)
    }

    // MARK: - Comparison

    @Test("comparisonDelta computes score differences")
    func comparisonDelta() throws {
        let vm = PostureHistoryViewModel()
        let older = makeRecord(
            date: Date().addingTimeInterval(-86400),
            frontMetrics: [makeMetric(type: .shoulderAsymmetry, value: 5.0, score: 70)]
        )
        let newer = makeRecord(
            date: Date(),
            frontMetrics: [makeMetric(type: .shoulderAsymmetry, value: 3.0, score: 85)]
        )

        let deltas = vm.comparisonDelta(older: older, newer: newer)

        #expect(deltas.count == 1)
        let delta = try #require(deltas.first)
        #expect(delta.type == .shoulderAsymmetry)
        #expect(delta.scoreDelta == 15)
        #expect(delta.isImproved == true)
    }

    @Test("comparisonDelta handles metrics present in only one record")
    func comparisonDeltaPartial() {
        let vm = PostureHistoryViewModel()
        let older = makeRecord(
            frontMetrics: [makeMetric(type: .shoulderAsymmetry, score: 70)]
        )
        let newer = makeRecord(
            sideMetrics: [makeMetric(type: .forwardHead, score: 60)]
        )

        let deltas = vm.comparisonDelta(older: older, newer: newer)

        #expect(deltas.count == 2)
        let asymmetry = deltas.first(where: { $0.type == .shoulderAsymmetry })
        #expect(asymmetry?.oldScore == 70)
        #expect(asymmetry?.newScore == nil)
        #expect(asymmetry?.scoreDelta == nil)
    }

    // MARK: - Selection

    @Test("toggleComparison adds and removes IDs")
    func toggleComparison() {
        let vm = PostureHistoryViewModel()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        vm.toggleComparison(id1)
        #expect(vm.comparisonSelection.contains(id1))

        vm.toggleComparison(id2)
        #expect(vm.canCompare)

        // Third ID should not be added (max 2)
        vm.toggleComparison(id3)
        #expect(!vm.comparisonSelection.contains(id3))

        // Remove first
        vm.toggleComparison(id1)
        #expect(!vm.comparisonSelection.contains(id1))
        #expect(!vm.canCompare)
    }

    // MARK: - Metric Filter

    @Test("loadHistory with metric filter uses per-metric chart data")
    func loadHistoryWithFilter() {
        let vm = PostureHistoryViewModel()
        vm.selectedMetricFilter = .forwardHead
        let now = Date()
        let records = [
            makeRecord(
                date: now.addingTimeInterval(-86400),
                overallScore: 70,
                sideMetrics: [makeMetric(type: .forwardHead, score: 60)]
            ),
            makeRecord(
                date: now,
                overallScore: 80,
                sideMetrics: [makeMetric(type: .forwardHead, score: 75)]
            ),
        ]

        vm.loadHistory(from: records)

        // Chart data should reflect metric scores, not overall scores
        #expect(vm.chartData.count == 2)
        #expect(vm.chartData[0].value == 60)
        #expect(vm.chartData[1].value == 75)
    }
}
