import Foundation
import Observation
import OSLog

/// ViewModel for CumulativeStressDetailView — loads period-based stress scores
/// from persisted HourlyScoreSnapshot data.
@Observable
@MainActor
final class CumulativeStressDetailViewModel {
    var selectedPeriod: TimePeriod = .month {
        didSet {
            if oldValue != selectedPeriod {
                resetScrollPosition()
                triggerReload()
            }
        }
    }
    var scrollPosition: Date = .now
    var showTrendLine: Bool = false {
        didSet { recalculateTrendLine() }
    }
    var chartData: [ChartDataPoint] = []
    var summaryStats: MetricSummary?
    var highlights: [Highlight] = []
    var isLoading = false

    private(set) var trendLineData: [ChartDataPoint]?
    private(set) var scrollDomain: ClosedRange<Date> = Date.now...Date.now
    private(set) var currentScore: CumulativeStressScore?

    private let scoreRefreshService: ScoreRefreshService?
    private let nowProvider: @Sendable () -> Date
    private var reloadRequestID = 0

    init(
        scoreRefreshService: ScoreRefreshService? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.scoreRefreshService = scoreRefreshService
        self.nowProvider = nowProvider
        recalculateScrollDomain()
    }

    func configure(stressScore: CumulativeStressScore) {
        self.currentScore = stressScore
        resetScrollPosition()
        recalculateScrollDomain()
    }

    func loadData() async {
        let requestID = beginReloadRequest()
        isLoading = true
        highlights = []
        defer { finishReloadRequest(requestID) }

        await loadSnapshotData(requestID: requestID)
        guard isCurrentReloadRequest(requestID) else { return }
        buildHighlights()
        recalculateTrendLine()
    }

    // MARK: - Scroll Position

    var visibleRangeLabel: String {
        selectedPeriod.visibleRangeLabel(from: scrollPosition)
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

    private func recalculateScrollDomain() {
        let range = extendedRange
        let upperBound = selectedPeriod.scrollDomainUpperBound(referenceDate: range.end)
        scrollDomain = range.start...max(range.end, upperBound)
    }

    private func recalculateTrendLine() {
        guard showTrendLine else { trendLineData = nil; return }
        trendLineData = MetricDetailViewModel.computeTrendLine(
            from: chartData, period: selectedPeriod, scrollPosition: scrollPosition
        )
    }

    // MARK: - Private

    private var reloadTask: Task<Void, Never>?

    private func triggerReload() {
        reloadRequestID += 1
        reloadTask?.cancel()
        reloadTask = Task { await loadData() }
    }

    private func beginReloadRequest() -> Int {
        reloadRequestID += 1
        return reloadRequestID
    }

    private func isCurrentReloadRequest(_ requestID: Int) -> Bool {
        requestID == reloadRequestID && !Task.isCancelled
    }

    private func finishReloadRequest(_ requestID: Int) {
        if requestID == reloadRequestID {
            isLoading = false
        }
    }

    /// Load stress scores from persisted HourlyScoreSnapshot data.
    /// Aggregates hourly snapshots to daily averages for chart display.
    private func loadSnapshotData(requestID: Int) async {
        guard let service = scoreRefreshService else { return }

        let range = extendedRange
        let calendar = Calendar.current

        // Fetch snapshots from ScoreRefreshService's ModelContext
        let snapshots = await service.fetchStressSnapshots(
            from: range.start,
            to: range.end
        )

        guard isCurrentReloadRequest(requestID) else { return }

        // Aggregate to daily averages
        let dailyGroups = Dictionary(grouping: snapshots) { snapshot in
            calendar.startOfDay(for: snapshot.date)
        }

        chartData = dailyGroups.compactMap { day, daySnapshots in
            let values = daySnapshots.compactMap(\.stressScore)
            guard !values.isEmpty else { return nil }
            let avg = values.reduce(0, +) / Double(values.count)
            return ChartDataPoint(date: day, value: avg)
        }
        .sorted { $0.date < $1.date }

        // Aggregate for longer periods
        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            chartData = HealthDataAggregator.aggregateByAverage(
                chartData, unit: selectedPeriod.aggregationUnit
            )
        }

        // Previous period for comparison
        let currentPeriodRange = selectedPeriod.dateRange(offset: 0)
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)

        let prevSnapshots = await service.fetchStressSnapshots(
            from: prevRange.start,
            to: prevRange.end
        )

        let prevDailyGroups = Dictionary(grouping: prevSnapshots) { snapshot in
            calendar.startOfDay(for: snapshot.date)
        }

        let previousValues = prevDailyGroups.compactMap { _, daySnapshots -> Double? in
            let values = daySnapshots.compactMap(\.stressScore)
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }

        let currentPeriodScores = chartData.filter {
            $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end
        }

        summaryStats = HealthDataAggregator.computeSummary(
            from: currentPeriodScores.map(\.value),
            previousPeriodValues: previousValues.isEmpty ? nil : previousValues
        )

        recalculateScrollDomain()
    }

    // MARK: - Highlights

    private func buildHighlights() {
        let currentPeriodRange = selectedPeriod.dateRange(offset: 0)
        let currentValues = chartData.filter {
            $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end
        }
        // For stress, high = worst day, low = best day
        highlights = HighlightBuilder.buildHighlights(
            from: currentValues,
            highLabel: String(localized: "Most stressed"),
            lowLabel: String(localized: "Least stressed")
        )
    }
}
