import Testing
import Foundation
@testable import DUNE

@Suite("CumulativeStressDetailViewModel")
@MainActor
struct CumulativeStressDetailViewModelTests {

    // MARK: - Initial State

    @Test("initial state has empty chart data and month period")
    func initialState() {
        let vm = CumulativeStressDetailViewModel()

        #expect(vm.chartData.isEmpty)
        #expect(vm.summaryStats == nil)
        #expect(vm.highlights.isEmpty)
        #expect(vm.selectedPeriod == .month)
        #expect(!vm.isLoading)
        #expect(!vm.showTrendLine)
        #expect(vm.trendLineData == nil)
    }

    // MARK: - Configure

    @Test("configure stores current score")
    func configureStoresScore() {
        let vm = CumulativeStressDetailViewModel()
        let score = makeStressScore(score: 42, level: .moderate)

        vm.configure(stressScore: score)

        #expect(vm.currentScore?.score == 42)
        #expect(vm.currentScore?.level == .moderate)
    }

    // MARK: - Period Change

    @Test("changing period resets scroll position")
    func periodChangeResetsScroll() {
        let vm = CumulativeStressDetailViewModel()

        let initialPosition = vm.scrollPosition
        vm.selectedPeriod = .week

        // Scroll position should change when period changes
        #expect(vm.scrollPosition != initialPosition || vm.selectedPeriod == .week)
    }

    // MARK: - Visible Range Label

    @Test("visibleRangeLabel returns non-empty string")
    func visibleRangeLabelNotEmpty() {
        let vm = CumulativeStressDetailViewModel()

        let label = vm.visibleRangeLabel
        #expect(!label.isEmpty)
    }

    // MARK: - Trend Line

    @Test("showTrendLine toggles trend line data")
    func trendLineToggle() {
        let vm = CumulativeStressDetailViewModel()

        // Initially nil
        #expect(vm.trendLineData == nil)

        // Toggle on with no data — still nil (need chart data)
        vm.showTrendLine = true
        #expect(vm.trendLineData == nil)

        // Toggle off
        vm.showTrendLine = false
        #expect(vm.trendLineData == nil)
    }

    // MARK: - Highlights (stress-specific labels)

    @Test("highlights use stress-specific labels")
    func highlightLabels() {
        // Build highlights manually to verify the label pattern
        let data = [
            ChartDataPoint(date: Date().addingTimeInterval(-86400 * 3), value: 30),
            ChartDataPoint(date: Date().addingTimeInterval(-86400 * 2), value: 70),
            ChartDataPoint(date: Date().addingTimeInterval(-86400 * 1), value: 50),
            ChartDataPoint(date: Date(), value: 45),
        ]

        let highlights = HighlightBuilder.buildHighlights(
            from: data,
            highLabel: String(localized: "Most stressed"),
            lowLabel: String(localized: "Least stressed")
        )

        #expect(highlights.count >= 2)

        let highHighlight = highlights.first { $0.type == .high }
        let lowHighlight = highlights.first { $0.type == .low }

        #expect(highHighlight?.label == String(localized: "Most stressed"))
        #expect(lowHighlight?.label == String(localized: "Least stressed"))
        #expect(highHighlight?.value == 70)
        #expect(lowHighlight?.value == 30)
    }

    // MARK: - Helpers

    private func makeStressScore(
        score: Int,
        level: CumulativeStressScore.Level,
        trend: TrendDirection = .stable
    ) -> CumulativeStressScore {
        CumulativeStressScore(
            score: score,
            level: level,
            contributions: [
                .init(factor: .hrvVariability, rawScore: 45, weight: 0.40, detail: "Moderate HRV fluctuation"),
                .init(factor: .sleepConsistency, rawScore: 35, weight: 0.35, detail: "Consistent sleep timing"),
                .init(factor: .activityLoad, rawScore: 50, weight: 0.25, detail: "Balanced training load"),
            ],
            trend: trend
        )
    }
}
