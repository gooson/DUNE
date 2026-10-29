import Foundation
import Observation

/// Displays recorded stress history without recalculating or backfilling scores.
@Observable
@MainActor
final class CumulativeStressDetailViewModel {
    typealias HistoryLoader = @MainActor (Date, Date, Calendar) async throws -> [(date: Date, score: Double)]

    var selectedPeriod: TimePeriod = .month {
        didSet {
            if oldValue != selectedPeriod { triggerReload() }
        }
    }
    var scrollPosition: Date = .now {
        didSet { recalculateVisibleState() }
    }
    var showTrendLine = false {
        didSet { recalculateTrendLine() }
    }
    private(set) var chartData: [ChartDataPoint] = []
    private(set) var summaryStats: MetricSummary?
    private(set) var highlights: [Highlight] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var visibleRangeLabel = ""
    private(set) var visibleChartPointCount = 0
    private(set) var trendLineData: [ChartDataPoint]?
    private(set) var scrollDomain: ClosedRange<Date> = Date.now...Date.now
    private(set) var currentScore: CumulativeStressScore?

    private var summarySourceData: [ChartDataPoint] = []
    private var visibleChartData: [ChartDataPoint] = []
    private var latestWindowStart: Date = .now
    private let scoreRefreshService: ScoreRefreshService?
    private let nowProvider: @Sendable () -> Date
    private let calendar: Calendar
    private let rangeFormatter: DateIntervalFormatter
    private let historyLoader: HistoryLoader?
    private var reloadRequestID = 0
    private var reloadTask: Task<Void, Never>?

    init(
        scoreRefreshService: ScoreRefreshService? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        calendar: Calendar = .current,
        historyLoader: HistoryLoader? = nil
    ) {
        self.scoreRefreshService = scoreRefreshService
        self.nowProvider = nowProvider
        self.calendar = calendar
        self.historyLoader = historyLoader
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = .current
        self.rangeFormatter = formatter
        resetScrollPosition()
    }

    func configure(stressScore: CumulativeStressScore) {
        currentScore = stressScore
        resetScrollPosition()
    }

    func loadData() async {
        reloadTask?.cancel()
        let requestID = beginReloadRequest()
        await loadSnapshotData(requestID: requestID)
    }

    // MARK: - Visible Window

    var canStepBackward: Bool {
        scrollPosition.addingTimeInterval(-selectedPeriod.visibleDomainSeconds) >= scrollDomain.lowerBound
    }

    var canStepForward: Bool {
        scrollPosition.addingTimeInterval(selectedPeriod.visibleDomainSeconds) <= latestWindowStart
    }

    func stepVisiblePeriod(by offset: Int) {
        guard (offset == -1 && canStepBackward) || (offset == 1 && canStepForward) else { return }
        scrollPosition = scrollPosition.addingTimeInterval(Double(offset) * selectedPeriod.visibleDomainSeconds)
    }

    private func resetScrollPosition() {
        let referenceDate = nowProvider()
        let window = ScoreDetailHistory.window(
            for: selectedPeriod, referenceDate: referenceDate, calendar: calendar
        )
        latestWindowStart = window.latestStart
        scrollDomain = window.domain
        scrollPosition = window.latestStart
    }

    private func recalculateVisibleState() {
        let duration = selectedPeriod.visibleDomainSeconds
        let end = scrollPosition.addingTimeInterval(duration)
        rangeFormatter.dateTemplate = selectedPeriod == .day ? "MMMdE" : "yMMMd"
        visibleRangeLabel = rangeFormatter.string(from: scrollPosition, to: end.addingTimeInterval(-1))
        visibleChartData = chartData.filter { $0.date >= scrollPosition && $0.date < end }
        visibleChartPointCount = visibleChartData.count
        summaryStats = ScoreDetailHistory.summary(
            from: summarySourceData, start: scrollPosition, duration: duration
        )
        let visibleSource = summarySourceData.filter { $0.date >= scrollPosition && $0.date < end }
        highlights = HighlightBuilder.buildHighlights(
            from: visibleSource,
            highLabel: String(localized: "Most stressed"),
            lowLabel: String(localized: "Least stressed")
        )
        recalculateTrendLine()
    }

    private func recalculateTrendLine() {
        guard showTrendLine else { trendLineData = nil; return }
        // Prefilter half-open boundaries before calling the shared regression helper.
        trendLineData = MetricDetailViewModel.computeTrendLine(
            from: visibleChartData, period: selectedPeriod, scrollPosition: scrollPosition
        )
    }

    // MARK: - Loading

    private func triggerReload() {
        reloadTask?.cancel()
        let requestID = beginReloadRequest()
        reloadTask = Task { await loadSnapshotData(requestID: requestID) }
    }

    private func beginReloadRequest() -> Int {
        reloadRequestID += 1
        isLoading = true
        loadError = nil
        summarySourceData = []
        chartData = []
        resetScrollPosition()
        return reloadRequestID
    }

    private func isCurrentReloadRequest(_ requestID: Int) -> Bool {
        requestID == reloadRequestID && !Task.isCancelled
    }

    private func loadSnapshotData(requestID: Int) async {
        defer {
            if requestID == reloadRequestID { isLoading = false }
        }
        guard isCurrentReloadRequest(requestID) else { return }
        let period = selectedPeriod
        let domain = scrollDomain
        let previousStart = domain.lowerBound.addingTimeInterval(-period.visibleDomainSeconds)
        // Fixed-duration pages can cross DST. Fetch the full first daily bucket.
        let fetchStart = period == .day ? previousStart : calendar.startOfDay(for: previousStart)

        do {
            let snapshots: [(date: Date, score: Double)]
            if let historyLoader {
                snapshots = try await historyLoader(fetchStart, domain.upperBound, calendar)
            } else if let scoreRefreshService {
                snapshots = try await scoreRefreshService.fetchStressHistory(
                    from: fetchStart, to: domain.upperBound, calendar: calendar
                )
            } else {
                snapshots = []
            }
            guard isCurrentReloadRequest(requestID) else { return }
            let source = Self.summaryPoints(from: snapshots, period: period, calendar: calendar)
            let plotSource = source.filter { $0.date >= domain.lowerBound && $0.date < domain.upperBound }
            let plot = period == .sixMonths || period == .year
                ? HealthDataAggregator.aggregateByAverage(plotSource, unit: period.aggregationUnit, calendar: calendar)
                : plotSource
            summarySourceData = source
            chartData = plot
            recalculateVisibleState()
        } catch is CancellationError {
            // Cancellation is not a failed or empty history result.
        } catch {
            guard isCurrentReloadRequest(requestID) else { return }
            loadError = String(localized: "Could not load data.")
        }
    }

    /// The service has already resolved duplicate hours. Keep every actual hour
    /// for D; for W and longer, each recorded day has equal statistical weight.
    static func summaryPoints(
        from snapshots: [(date: Date, score: Double)],
        period: TimePeriod,
        calendar: Calendar = .current
    ) -> [ChartDataPoint] {
        let hourly = snapshots.compactMap { snapshot -> ChartDataPoint? in
            guard snapshot.score.isFinite, (0...100).contains(snapshot.score) else { return nil }
            return ChartDataPoint(date: snapshot.date, value: snapshot.score)
        }.sorted { $0.date < $1.date } // oldest-first
        guard period != .day else { return hourly }
        return HealthDataAggregator.aggregateByAverage(hourly, unit: .day, calendar: calendar)
    }
}
