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
    var summaryStats: MetricSummary?
    var highlights: [Highlight] = []
    var isLoading = false
    var errorMessage: String?

    private(set) var trendLineData: [ChartDataPoint]?
    private(set) var scrollDomain: ClosedRange<Date> = Date.now...Date.now
    private(set) var currentScore: ConditionScore?
    private(set) var limitedHistoryStartDate: Date?

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
        recalculateScrollDomain()
    }

    func configure(score: ConditionScore) {
        self.currentScore = score
        limitedHistoryStartDate = nil
        resetScrollPosition()
        recalculateScrollDomain()
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
        selectedPeriod.visibleRangeLabel(from: scrollPosition)
    }

    var visibleChartPointCount: Int {
        let end = scrollPosition.addingTimeInterval(selectedPeriod.visibleDomainSeconds)
        return chartData.count { $0.date >= scrollPosition && $0.date < end }
    }

    private func resetScrollPosition() {
        if selectedPeriod == .day {
            // Rolling 24h: scroll to show the full 24h window starting from now-24h
            scrollPosition = nowProvider().addingTimeInterval(-ScoreRefreshService.rollingWindowSeconds)
        } else {
            let range = selectedPeriod.dateRange(offset: 0)
            scrollPosition = range.start
        }
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
        let daysInRange = max(1, calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 7)
        let currentRHRStart = calendar.date(
            byAdding: .day,
            value: -CalculateConditionScoreUseCase.conditionWindowDays,
            to: range.start
        ) ?? range.start

        async let currentSamplesTask = hrvService.fetchHRVSamples(
            days: daysInRange + CalculateConditionScoreUseCase.conditionWindowDays
        )
        async let currentRHRTask = hrvService.fetchRHRCollection(
            start: currentRHRStart,
            end: range.end,
            interval: DateComponents(day: 1)
        )

        // Previous period for comparison (based on current period, not extended)
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)
        let prevDays = max(1, calendar.dateComponents([.day], from: prevRange.start, to: prevRange.end).day ?? 7)
        let currentPeriodDays = max(1, calendar.dateComponents(
            [.day],
            from: selectedPeriod.dateRange(offset: 0).start,
            to: selectedPeriod.dateRange(offset: 0).end
        ).day ?? 7)
        let prevRHRStart = calendar.date(
            byAdding: .day,
            value: -CalculateConditionScoreUseCase.conditionWindowDays,
            to: prevRange.start
        ) ?? prevRange.start
        async let prevSamplesTask = hrvService.fetchHRVSamples(
            days: currentPeriodDays + prevDays + CalculateConditionScoreUseCase.conditionWindowDays
        )
        async let prevRHRTask = hrvService.fetchRHRCollection(
            start: prevRHRStart,
            end: prevRange.end,
            interval: DateComponents(day: 1)
        )

        let allSamples = try await currentSamplesTask
        let allRHR = try await currentRHRTask
        let allSamplesForPrev = try await prevSamplesTask
        let allRHRForPrev = try await prevRHRTask

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

        // Compute daily scores for the previous period
        let previousScores = computeDailyScores(
            samples: allSamplesForPrev,
            rhrCollection: allRHRForPrev,
            range: (start: prevRange.start, end: prevRange.end),
            calendar: calendar
        )

        guard isCurrentReloadRequest(requestID) else { return }
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

        // Summary stats from current period only
        let currentPeriodScores = allScores.filter {
            $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end
        }

        summaryStats = HealthDataAggregator.computeSummary(
            from: currentPeriodScores.map(\.value),
            previousPeriodValues: previousScores.isEmpty ? nil : previousScores.map(\.value)
        )

        recalculateScrollDomain()
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
        let now = nowProvider()
        let historyStart = extendedRange.start
        let displayStart = max(historyStart, limitedHistoryStartDate ?? historyStart)
        let twentyFourHoursAgo = now.addingTimeInterval(-ScoreRefreshService.rollingWindowSeconds)
        let fortyEightHoursAgo = now.addingTimeInterval(-ScoreRefreshService.rollingWindowSeconds * 2)
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
        let hourlyEvaluationDates = Dictionary(grouping: samples.filter { $0.date >= displayStart && $0.date <= now }) {
            calendar.dateInterval(of: .hour, for: $0.date)?.start ?? $0.date
        }
        .compactMap { hourDate, samplesInHour in
            samplesInHour.map(\.date).max().map { (hourDate: hourDate, evaluationDate: $0) }
        }
        .sorted { $0.hourDate < $1.hourDate }

        let snapshots = await scoreRefreshService?.fetchConditionSnapshots(from: displayStart, to: now) ?? []
        let recordedHours = Set(snapshots.map {
            calendar.dateInterval(of: .hour, for: $0.date)?.start ?? $0.date
        })
        let currentHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let missingHours = hourlyEvaluationDates.filter {
            !recordedHours.contains($0.hourDate) && (currentScore == nil || $0.hourDate != currentHour)
        }
        let calculatedPoints = await Task.detached(priority: .userInitiated) {
            let useCase = CalculateConditionScoreUseCase()
            return missingHours.compactMap { item -> ChartDataPoint? in
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
        }.value
        guard isCurrentReloadRequest(requestID) else { return }
        chartData = Self.mergedHourlyPoints(
            calculated: calculatedPoints,
            snapshots: snapshots,
            currentScore: currentScore,
            now: now,
            calendar: calendar
        )

        let values = chartData.filter { $0.date >= twentyFourHoursAgo }.map(\.value)
        let previousValues = chartData.filter {
            $0.date >= fortyEightHoursAgo && $0.date < twentyFourHoursAgo
        }.map(\.value)
        summaryStats = HealthDataAggregator.computeSummary(
            from: values,
            previousPeriodValues: previousValues.isEmpty ? nil : previousValues
        )

        // Sub-scores not shown for hourly view
        hrvTrend = []
        rhrTrend = []
        recalculateScrollDomain()
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
