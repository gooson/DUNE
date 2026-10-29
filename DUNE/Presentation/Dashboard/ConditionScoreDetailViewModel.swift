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
    var scrollPosition: Date = .now {
        didSet { recalculateTrendLine() }
    }
    var showTrendLine: Bool = false {
        didSet { recalculateTrendLine() }
    }
    var chartData: [ChartDataPoint] = []
    var hrvTrend: [ChartDataPoint] = []
    var rhrTrend: [ChartDataPoint] = []
    var highlights: [Highlight] = []
    var isLoading = false
    var errorMessage: String?

    private(set) var trendLineData: [ChartDataPoint]?
    private(set) var scrollDomain: ClosedRange<Date> = Date.now...Date.now
    private(set) var currentScore: ConditionScore?
    private(set) var limitedHistoryStartDate: Date?

    private var summarySourceData: [ChartDataPoint] = []

    private let hrvService: HRVQuerying
    private let historyService: any MetricHistoryQuerying
    private let scoreUseCase = CalculateConditionScoreUseCase()
    private let scoreRefreshService: ScoreRefreshService?
    private let nowProvider: @Sendable () -> Date
    private var reloadRequestID = 0

    init(
        hrvService: HRVQuerying? = nil,
        historyService: (any MetricHistoryQuerying)? = nil,
        healthKitManager: HealthKitManager = .shared,
        scoreRefreshService: ScoreRefreshService? = nil,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.historyService = historyService ?? MetricHistoryQueryService(manager: healthKitManager)
        self.scoreRefreshService = scoreRefreshService
        self.nowProvider = nowProvider
        resetScrollPosition()
    }

    func configure(score: ConditionScore) {
        self.currentScore = score
        limitedHistoryStartDate = nil
        resetScrollPosition()
    }

    func loadData() async {
        let requestID = beginReloadRequest()
        isLoading = true
        errorMessage = nil
        highlights = []
        defer { finishReloadRequest(requestID) }

        do {
            async let hrvLimit = historyService.limitedReadStartDate(for: .hrv)
            async let rhrLimit = historyService.limitedReadStartDate(for: .rhr)
            let (hrvStart, rhrStart) = await (hrvLimit, rhrLimit)
            guard isCurrentReloadRequest(requestID) else { return }
            limitedHistoryStartDate = [hrvStart, rhrStart].compactMap { $0 }.max()
            if selectedPeriod == .day {
                try await loadHourlyData(requestID: requestID)
            } else {
                try await loadScoreData(requestID: requestID)
            }
            guard isCurrentReloadRequest(requestID) else { return }
            buildHighlights()
            recalculateTrendLine()
        } catch {
            guard isCurrentReloadRequest(requestID) else { return }
            AppLogger.ui.error("ConditionScoreDetail load failed: \(error.localizedDescription)")
            errorMessage = String(localized: "Could not load data.")
        }
    }

    // MARK: - Scroll Position

    /// Label showing the currently visible date range, like Health app.
    var visibleRangeLabel: String {
        Self.visibleRangeLabel(
            from: scrollPosition, period: selectedPeriod
        )
    }

    var visibleChartPointCount: Int {
        let end = scrollPosition.addingTimeInterval(selectedPeriod.visibleDomainSeconds)
        return chartData.count { $0.date >= scrollPosition && $0.date < end }
    }

    /// Summary follows the plotted window, using daily/hourly values before plot aggregation.
    var visibleSummaryStats: MetricSummary? {
        guard !isLoading else { return nil }
        return Self.makeVisibleSummary(
            from: summarySourceData,
            start: scrollPosition,
            duration: selectedPeriod.visibleDomainSeconds
        )
    }

    static func makeVisibleSummary(
        from points: [ChartDataPoint], start: Date, duration: TimeInterval
    ) -> MetricSummary? {
        ScoreDetailHistory.summary(from: points, start: start, duration: duration)
    }

    private var windowReferenceDate: Date = .now
    private var latestWindowStart: Date = .now

    var canStepBackward: Bool {
        scrollPosition.addingTimeInterval(-selectedPeriod.visibleDomainSeconds) >= scrollDomain.lowerBound
    }

    var canStepForward: Bool {
        scrollPosition.addingTimeInterval(selectedPeriod.visibleDomainSeconds) <= latestWindowStart
    }

    func stepVisiblePeriod(by offset: Int) {
        guard (offset == -1 && canStepBackward) || (offset == 1 && canStepForward) else { return }
        // A partial jump at either boundary would overlap the adjacent summary window.
        scrollPosition = scrollPosition.addingTimeInterval(Double(offset) * selectedPeriod.visibleDomainSeconds)
    }

    /// Uses the chart's fixed duration for every page, including across DST and leap years.
    static func historyWindow(
        for period: TimePeriod,
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> (latestStart: Date, domain: ClosedRange<Date>) {
        ScoreDetailHistory.window(for: period, referenceDate: referenceDate, calendar: calendar)
    }

    static func visibleRangeLabel(
        from start: Date,
        period: TimePeriod,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let displayEnd = start.addingTimeInterval(period.visibleDomainSeconds - 1)
        if calendar.isDate(start, inSameDayAs: displayEnd) {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = locale
            formatter.setLocalizedDateFormatFromTemplate(period == .day ? "MMMdE" : "yMMMd")
            return formatter.string(from: start)
        }
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.dateTemplate = period == .day ? "MMMdE" : "yMMMd"
        return formatter.string(from: start, to: displayEnd)
    }

    private func resetScrollPosition() {
        windowReferenceDate = nowProvider()
        let window = Self.historyWindow(for: selectedPeriod, referenceDate: windowReferenceDate)
        latestWindowStart = window.latestStart
        scrollDomain = window.domain
        scrollPosition = window.latestStart
    }

    // MARK: - Extended Range

    private var extendedRange: (start: Date, end: Date) {
        let bufferRange = selectedPeriod.dateRange(
            offset: -selectedPeriod.scrollBufferPeriods, referenceDate: windowReferenceDate
        )
        // Preserve the calendar preload used by highlights/subscores, adding any
        // history required by complete fixed-duration chart pages.
        return (start: min(bufferRange.start, scrollDomain.lowerBound), end: windowReferenceDate)
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
        isLoading = false
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

    private func loadScoreData(requestID: Int) async throws {
        let range = extendedRange

        // Fetch all HRV samples for the extended period
        let calendar = Calendar.current
        let baselineStart = calendar.date(
            byAdding: .day,
            value: -CalculateConditionScoreUseCase.conditionWindowDays,
            to: range.start
        ) ?? range.start

        async let currentSamplesTask = hrvService.fetchHRVSamples(
            start: baselineStart, end: range.end
        )
        async let currentRHRTask = hrvService.fetchRHRCollection(
            start: baselineStart,
            end: range.end,
            interval: DateComponents(day: 1)
        )

        let allSamples = try await currentSamplesTask
        let allRHR = try await currentRHRTask

        // Compute daily scores for the extended range
        var allScores = computeDailyScores(
            samples: allSamples,
            rhrCollection: allRHR,
            range: range,
            calendar: calendar
        )
        // The hero and detail ring show the latest intraday score. Keep today's
        // daily chart point on the same value when a daily baseline exists.
        if let currentScore,
           calendar.isDate(currentScore.date, inSameDayAs: nowProvider()),
           let todayIndex = allScores.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: currentScore.date) }) {
            allScores[todayIndex] = ChartDataPoint(
                date: allScores[todayIndex].date,
                value: Double(currentScore.score)
            )
        }

        guard isCurrentReloadRequest(requestID) else { return }
        summarySourceData = allScores
        chartData = allScores

        // Sub-score trends: daily HRV averages and RHR averages within current period
        let currentPeriodRange = selectedPeriod.dateRange(offset: 0)
        hrvTrend = HealthDataAggregator.buildHRVDailyAverages(
            from: allSamples,
            start: currentPeriodRange.start,
            end: currentPeriodRange.end,
            calendar: calendar
        )
        rhrTrend = HealthDataAggregator.buildRHRDailyPoints(from: allRHR)
            .filter { $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end }

        // Aggregate for longer periods
        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            chartData = HealthDataAggregator.aggregateByAverage(
                chartData, unit: selectedPeriod.aggregationUnit
            )
        }
    }

    /// Computes daily condition scores within the given range.
    /// For each day, uses all HRV samples up to (and including) that day to calculate a score.
    /// Uses cursor-based iteration (O(n+m)) instead of per-day filtering (O(n*m)).
    private func computeDailyScores(
        samples: [HRVSample],
        rhrCollection: [(date: Date, min: Double, max: Double, average: Double)],
        range: (start: Date, end: Date),
        calendar: Calendar
    ) -> [ChartDataPoint] {
        let sortedSamples = samples.sorted { $0.date < $1.date }
        let sortedRHR = rhrCollection
            .filter { $0.average > 0 && $0.average.isFinite }
            .map { CalculateConditionScoreUseCase.Input.RHRDailyAverage(date: $0.date, value: $0.average) }
            .sorted { $0.date < $1.date }
        var results: [ChartDataPoint] = []
        let startDay = calendar.startOfDay(for: range.start)
        let endDay = calendar.startOfDay(for: range.end)

        var sampleCursor = 0
        var cumulativeSamples: [HRVSample] = []
        var rhrCursor = 0
        var cumulativeRHR: [CalculateConditionScoreUseCase.Input.RHRDailyAverage] = []

        var current = startDay
        while current <= endDay {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }

            // Advance cursor: add new samples up to this day (amortized O(1) per day)
            while sampleCursor < sortedSamples.count && sortedSamples[sampleCursor].date < nextDay {
                cumulativeSamples.append(sortedSamples[sampleCursor])
                sampleCursor += 1
            }

            while rhrCursor < sortedRHR.count && sortedRHR[rhrCursor].date < nextDay {
                cumulativeRHR.append(sortedRHR[rhrCursor])
                rhrCursor += 1
            }

            let input = CalculateConditionScoreUseCase.Input(
                hrvSamples: cumulativeSamples,
                rhrDailyAverages: cumulativeRHR,
                todayRHR: nil,
                yesterdayRHR: nil,
                displayRHR: cumulativeRHR.last?.value,
                displayRHRDate: cumulativeRHR.last?.date
            )
            let output = scoreUseCase.execute(input: input)

            if let score = output.score {
                results.append(ChartDataPoint(date: current, value: Double(score.score)))
            }

            current = nextDay
        }

        return results
    }

    // MARK: - Hourly Data (Day Period)

    private func loadHourlyData(requestID: Int) async throws {
        let calendar = Calendar.current
        let now = windowReferenceDate
        let historyStart = extendedRange.start
        let displayStart = max(historyStart, limitedHistoryStartDate ?? historyStart)
        let baselineStart = calendar.date(
            byAdding: .day,
            value: -CalculateConditionScoreUseCase.conditionWindowDays,
            to: historyStart
        ) ?? historyStart

        async let samplesTask = hrvService.fetchHRVSamples(start: baselineStart, end: now)
        async let rhrTask = hrvService.fetchRHRCollection(
            start: baselineStart,
            end: now,
            interval: DateComponents(day: 1)
        )

        let (samples, rhrCollection) = try await (samplesTask, rhrTask)
        let rhrDailyAverages = rhrCollection
            .filter { $0.average > 0 && $0.average.isFinite }
            .map { CalculateConditionScoreUseCase.Input.RHRDailyAverage(date: $0.date, value: $0.average) }
        let snapshots = await scoreRefreshService?.fetchConditionSnapshots(from: displayStart, to: now) ?? []
        let recordedHours = Set(snapshots.map {
            calendar.dateInterval(of: .hour, for: $0.date)?.start ?? $0.date
        })
        let hasCurrentScore = currentScore != nil
        let calculatedPoints = await Task.detached(priority: .userInitiated) {
            Self.calculatedHourlyPoints(
                samples: samples,
                rhrDailyAverages: rhrDailyAverages,
                displayStart: displayStart,
                now: now,
                recordedHours: recordedHours,
                hasCurrentScore: hasCurrentScore,
                calendar: calendar
            )
        }.value
        guard isCurrentReloadRequest(requestID) else { return }
        chartData = Self.mergedHourlyPoints(
            calculated: calculatedPoints,
            snapshots: snapshots,
            currentScore: currentScore,
            now: now,
            calendar: calendar
        )

        summarySourceData = chartData

        // Sub-scores not shown for hourly view
        hrvTrend = []
        rhrTrend = []
    }

    /// Evaluates only hours backed by HRV measurements. Both Today and detail
    /// use this path so their rolling-day curves contain the same real points.
    nonisolated static func calculatedHourlyPoints(
        samples: [HRVSample],
        rhrDailyAverages: [CalculateConditionScoreUseCase.Input.RHRDailyAverage],
        displayStart: Date,
        now: Date,
        recordedHours: Set<Date>,
        hasCurrentScore: Bool,
        calendar: Calendar = .current
    ) -> [ChartDataPoint] {
        let hourlyEvaluationDates = Dictionary(grouping: samples.filter { $0.date >= displayStart && $0.date <= now }) {
            calendar.dateInterval(of: .hour, for: $0.date)?.start ?? $0.date
        }
        .compactMap { hourDate, samplesInHour in
            samplesInHour.map(\.date).max().map { (hourDate: hourDate, evaluationDate: $0) }
        }
        .sorted { $0.hourDate < $1.hourDate }
        let currentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let useCase = CalculateConditionScoreUseCase()
        return hourlyEvaluationDates.compactMap { item -> ChartDataPoint? in
            guard !recordedHours.contains(item.hourDate),
                  !hasCurrentScore || item.hourDate != currentHour else { return nil }
            let intraday = useCase.executeIntraday(input: .init(
                hrvSamples: samples,
                rhrDailyAverages: rhrDailyAverages,
                evaluationDate: item.evaluationDate
            ))
            let score = intraday.score ?? useCase.execute(input: .init(
                hrvSamples: samples.filter { $0.date <= item.evaluationDate },
                rhrDailyAverages: rhrDailyAverages.filter { $0.date <= item.evaluationDate },
                todayRHR: nil,
                yesterdayRHR: nil,
                evaluationDate: item.evaluationDate
            )).score
            guard let score else { return nil }
            return ChartDataPoint(date: item.hourDate, value: Double(score.score))
        }
    }

    static func mergedHourlyPoints(
        calculated: [ChartDataPoint],
        snapshots: [(date: Date, score: Double)],
        currentScore: ConditionScore?,
        now: Date,
        calendar: Calendar = .current
    ) -> [ChartDataPoint] {
        var pointsByHour = Dictionary(uniqueKeysWithValues: calculated.map { ($0.date, $0) })
        for snapshot in snapshots {
            let hour = calendar.dateInterval(of: .hour, for: snapshot.date)?.start ?? snapshot.date
            pointsByHour[hour] = ChartDataPoint(date: hour, value: snapshot.score)
        }
        if let currentScore {
            let hour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
            pointsByHour[hour] = ChartDataPoint(date: hour, value: Double(currentScore.score))
        }
        return pointsByHour.values.sorted { $0.date < $1.date }
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
