import Foundation
import Observation
import OSLog

/// ViewModel for ConditionScoreDetailView — loads period-based daily scores.
/// Uses CalculateConditionScoreUseCase to compute daily scores from HRV samples.
@Observable
@MainActor
final class ConditionScoreDetailViewModel {
    var selectedPeriod: TimePeriod = .week {
        didSet {
            if oldValue != selectedPeriod {
                resetScrollPosition()
                triggerReload()
            }
        }
    }
    var scrollPosition: Date = .now
    var showTrendLine: Bool = false
    var chartData: [ChartDataPoint] = []
    var summaryStats: MetricSummary?
    var highlights: [Highlight] = []
    var isLoading = false
    var errorMessage: String?

    private(set) var currentScore: ConditionScore?

    private let hrvService: HRVQuerying
    private let scoreUseCase = CalculateConditionScoreUseCase()

    init(
        hrvService: HRVQuerying? = nil,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
    }

    func configure(score: ConditionScore) {
        self.currentScore = score
    }

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await loadScoreData()
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            buildHighlights()
        } catch {
            AppLogger.ui.error("ConditionScoreDetail load failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Scroll Position

    /// Label showing the currently visible date range, like Health app.
    var visibleRangeLabel: String {
        selectedPeriod.visibleRangeLabel(from: scrollPosition)
    }

    /// Trend line data points (linear regression) for the visible chart data.
    var trendLineData: [ChartDataPoint]? {
        guard showTrendLine else { return nil }
        return MetricDetailViewModel.computeTrendLine(
            from: chartData, period: selectedPeriod, scrollPosition: scrollPosition
        )
    }

    private func resetScrollPosition() {
        let range = selectedPeriod.dateRange(offset: 0)
        scrollPosition = range.start
    }

    // MARK: - Extended Range

    private var extendedRange: (start: Date, end: Date) {
        let currentRange = selectedPeriod.dateRange(offset: 0)
        let bufferRange = selectedPeriod.dateRange(offset: -selectedPeriod.scrollBufferPeriods)
        return (start: bufferRange.start, end: currentRange.end)
    }

    // MARK: - Private

    private var reloadTask: Task<Void, Never>?

    private func triggerReload() {
        reloadTask?.cancel()
        reloadTask = Task { await loadData() }
    }

    private func loadScoreData() async throws {
        let range = extendedRange

        // Fetch all HRV samples for the extended period
        let calendar = Calendar.current
        let daysInRange = max(1, calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 7)

        async let currentSamplesTask = hrvService.fetchHRVSamples(days: daysInRange + 7)

        // Previous period for comparison (based on current period, not extended)
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)
        let prevDays = max(1, calendar.dateComponents([.day], from: prevRange.start, to: prevRange.end).day ?? 7)
        let currentPeriodDays = max(1, calendar.dateComponents(
            [.day],
            from: selectedPeriod.dateRange(offset: 0).start,
            to: selectedPeriod.dateRange(offset: 0).end
        ).day ?? 7)
        async let prevSamplesTask = hrvService.fetchHRVSamples(days: currentPeriodDays + prevDays + 7)

        let allSamples = try await currentSamplesTask
        let allSamplesForPrev = try await prevSamplesTask

        // Compute daily scores for the extended range
        let allScores = computeDailyScores(
            samples: allSamples,
            range: range,
            calendar: calendar
        )

        // Compute daily scores for the previous period
        let previousScores = computeDailyScores(
            samples: allSamplesForPrev,
            range: (start: prevRange.start, end: prevRange.end),
            calendar: calendar
        )

        chartData = allScores

        // Aggregate for longer periods
        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            chartData = HealthDataAggregator.aggregateByAverage(
                chartData, unit: selectedPeriod.aggregationUnit
            )
        }

        // Summary stats from current period only
        let currentPeriodRange = selectedPeriod.dateRange(offset: 0)
        let currentPeriodScores = allScores.filter {
            $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end
        }

        summaryStats = HealthDataAggregator.computeSummary(
            from: currentPeriodScores.map(\.value),
            previousPeriodValues: previousScores.isEmpty ? nil : previousScores.map(\.value)
        )
    }

    /// Computes daily condition scores within the given range.
    /// For each day, uses all HRV samples up to (and including) that day to calculate a score.
    /// Uses cursor-based iteration (O(n+m)) instead of per-day filtering (O(n*m)).
    private func computeDailyScores(
        samples: [HRVSample],
        range: (start: Date, end: Date),
        calendar: Calendar
    ) -> [ChartDataPoint] {
        let sortedSamples = samples.sorted { $0.date < $1.date }
        var results: [ChartDataPoint] = []
        let startDay = calendar.startOfDay(for: range.start)
        let endDay = calendar.startOfDay(for: range.end)

        var sampleCursor = 0
        var cumulativeSamples: [HRVSample] = []

        var current = startDay
        while current <= endDay {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }

            // Advance cursor: add new samples up to this day (amortized O(1) per day)
            while sampleCursor < sortedSamples.count && sortedSamples[sampleCursor].date < nextDay {
                cumulativeSamples.append(sortedSamples[sampleCursor])
                sampleCursor += 1
            }

            let input = CalculateConditionScoreUseCase.Input(
                hrvSamples: cumulativeSamples,
                todayRHR: nil,
                yesterdayRHR: nil
            )
            let output = scoreUseCase.execute(input: input)

            if let score = output.score {
                results.append(ChartDataPoint(date: current, value: Double(score.score)))
            }

            current = nextDay
        }

        return results
    }

    // MARK: - Highlights

    private func buildHighlights() {
        let currentPeriodRange = selectedPeriod.dateRange(offset: 0)
        let currentValues = chartData.filter {
            $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end
        }
        highlights = HighlightBuilder.buildHighlights(
            from: currentValues,
            highLabel: String(localized: "Best day"),
            lowLabel: String(localized: "Lowest day")
        )
    }
}
