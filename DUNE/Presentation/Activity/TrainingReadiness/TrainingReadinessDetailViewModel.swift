import Foundation
import Observation
import OSLog

/// ViewModel for the Training Readiness detail view.
/// Self-contained: fetches HRV/RHR/Sleep data directly from HealthKit.
/// Supports period selection and produces DotLineChartView-ready data.
@Observable
@MainActor
final class TrainingReadinessDetailViewModel {
    var selectedPeriod: TimePeriod = .week {
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

    var readiness: TrainingReadiness?
    var chartData: [ChartDataPoint] = []
    var hrvTrend: [ChartDataPoint] = []
    var rhrTrend: [ChartDataPoint] = []
    var sleepTrend: [ChartDataPoint] = []
    var summaryStats: MetricSummary?
    var highlights: [Highlight] = []
    var isLoading = false
    var errorMessage: String?

    private(set) var trendLineData: [ChartDataPoint]?
    private(set) var scrollDomain: ClosedRange<Date> = Date.now...Date.now

    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying
    private let scoreRefreshService: ScoreRefreshService?

    init(
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        healthKitManager: HealthKitManager = .shared,
        scoreRefreshService: ScoreRefreshService? = nil
    ) {
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        self.scoreRefreshService = scoreRefreshService
        recalculateScrollDomain()
    }

    func configure(readiness: TrainingReadiness?) {
        self.readiness = readiness
        resetScrollPosition()
        recalculateScrollDomain()
    }

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        highlights = []

        do {
            if selectedPeriod == .day {
                await loadHourlyData()
            } else {
                try await loadReadinessData()
            }
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            buildHighlights()
            recalculateTrendLine()
        } catch {
            AppLogger.ui.error("ReadinessDetail load failed: \(error.localizedDescription)")
            errorMessage = String(localized: "Could not load data.")
        }

        isLoading = false
    }

    // MARK: - Scroll Position

    var visibleRangeLabel: String {
        selectedPeriod.visibleRangeLabel(from: scrollPosition)
    }

    private func resetScrollPosition() {
        if selectedPeriod == .day {
            scrollPosition = Date().addingTimeInterval(-ScoreRefreshService.rollingWindowSeconds)
        } else {
            let range = selectedPeriod.dateRange(offset: 0)
            scrollPosition = range.start
        }
    }

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
        reloadTask?.cancel()
        isLoading = false
        reloadTask = Task { await loadData() }
    }

    // MARK: - Hourly Data (Day Period)

    private func loadHourlyData() async {
        guard let service = scoreRefreshService else {
            chartData = []
            summaryStats = nil
            return
        }

        let snapshots = await service.fetchRollingSnapshots(hoursBack: 48)
        let now = Date()
        let currentStart = now.addingTimeInterval(-ScoreRefreshService.rollingWindowSeconds)

        let currentSnapshots = snapshots.filter { $0.date >= currentStart && $0.date <= now }
        let previousSnapshots = snapshots.filter { $0.date < currentStart }

        chartData = currentSnapshots.compactMap { snap in
            guard let score = snap.readinessScore else { return nil }
            return ChartDataPoint(date: snap.date, value: score)
        }

        let values = chartData.map(\.value)
        let previousValues = previousSnapshots.compactMap(\.readinessScore)
        summaryStats = HealthDataAggregator.computeSummary(
            from: values,
            previousPeriodValues: previousValues.isEmpty ? nil : previousValues
        )

        // Sub-scores not shown for hourly view
        hrvTrend = []
        rhrTrend = []
        sleepTrend = []

        recalculateScrollDomain()
    }

    private func loadReadinessData() async throws {
        let calendar = Calendar.current
        let range = extendedRange
        let daysInRange = max(1, calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 14)

        // Previous period
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)
        let prevDays = max(1, calendar.dateComponents([.day], from: prevRange.start, to: prevRange.end).day ?? 14)

        // Fetch HRV once for full window (current + previous), partition by date later
        let totalHRVDays = daysInRange + prevDays
        async let allHRVTask = hrvService.fetchHRVSamples(days: totalHRVDays)
        async let rhrTask = hrvService.fetchRHRCollection(
            start: range.start,
            end: range.end,
            interval: DateComponents(day: 1)
        )
        async let sleepTask = sleepService.fetchDailySleepDurations(
            start: range.start,
            end: range.end
        )
        async let prevRHRTask = hrvService.fetchRHRCollection(
            start: prevRange.start,
            end: prevRange.end,
            interval: DateComponents(day: 1)
        )
        async let prevSleepTask = sleepService.fetchDailySleepDurations(
            start: prevRange.start,
            end: prevRange.end
        )

        let allHRV = try await allHRVTask
        let (allRHR, allSleep) = try await (rhrTask, sleepTask)
        let (prevRHR, prevSleep) = try await (prevRHRTask, prevSleepTask)

        // Build sub-score arrays using shared helpers
        let currentPeriodRange = selectedPeriod.dateRange(offset: 0)
        let currentHRV = HealthDataAggregator.buildHRVDailyAverages(from: allHRV, start: range.start, end: range.end, calendar: calendar)
        let currentRHR = HealthDataAggregator.buildRHRDailyPoints(from: allRHR)
        let currentSleep = allSleep
            .map { ChartDataPoint(date: $0.date, value: Swift.max(0, Swift.min($0.totalMinutes / 60.0, 24))) }
            .sorted { $0.date < $1.date }

        hrvTrend = currentHRV.filter { $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end }
        rhrTrend = currentRHR.filter { $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end }
        sleepTrend = currentSleep.filter { $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end }

        // Build readiness trend
        let allScores = buildReadinessTrend(hrv: currentHRV, rhr: currentRHR, sleep: currentSleep)
        chartData = allScores

        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            chartData = HealthDataAggregator.aggregateByAverage(
                chartData, unit: selectedPeriod.aggregationUnit
            )
        }

        // Previous period — partition allHRV by date
        let prevHRVDaily = HealthDataAggregator.buildHRVDailyAverages(from: allHRV, start: prevRange.start, end: prevRange.end, calendar: calendar)
        let prevRHRDaily = HealthDataAggregator.buildRHRDailyPoints(from: prevRHR)
        let prevSleepDaily = prevSleep
            .map { ChartDataPoint(date: $0.date, value: Swift.max(0, Swift.min($0.totalMinutes / 60.0, 24))) }
        let previousScores = buildReadinessTrend(hrv: prevHRVDaily, rhr: prevRHRDaily, sleep: prevSleepDaily)

        let currentPeriodScores = allScores.filter {
            $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end
        }
        summaryStats = HealthDataAggregator.computeSummary(
            from: currentPeriodScores.map(\.value),
            previousPeriodValues: previousScores.isEmpty ? nil : previousScores.map(\.value)
        )

        recalculateScrollDomain()
    }

    // MARK: - Readiness Trend Approximation

    /// Approximate scoring weights for the trend chart.
    private enum ApproxWeights {
        static let hrv: Double = 0.4
        static let rhr: Double = 0.3
        static let sleep: Double = 0.3
    }

    private func buildReadinessTrend(
        hrv: [ChartDataPoint],
        rhr: [ChartDataPoint],
        sleep: [ChartDataPoint]
    ) -> [ChartDataPoint] {
        guard !hrv.isEmpty else { return [] }

        let calendar = Calendar.current
        let hrvByDay = Dictionary(hrv.map { (calendar.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { _, last in last })
        let rhrByDay = Dictionary(rhr.map { (calendar.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { _, last in last })
        let sleepByDay = Dictionary(sleep.map { (calendar.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { _, last in last })

        let hrvValues = hrv.map(\.value)
        let hrvMean = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let hrvStdDev: Double = {
            let variance = hrvValues.map { ($0 - hrvMean) * ($0 - hrvMean) }.reduce(0, +) / Double(hrvValues.count)
            return sqrt(Swift.max(variance, 0.01))
        }()

        let rhrValues = rhr.map(\.value)
        let rhrMean = rhrValues.isEmpty ? 0 : rhrValues.reduce(0, +) / Double(rhrValues.count)

        let allDays = Set(
            hrv.map { calendar.startOfDay(for: $0.date) }
            + rhr.map { calendar.startOfDay(for: $0.date) }
        ).sorted()

        return allDays.compactMap { day in
            guard let hrvValue = hrvByDay[day] else { return nil }

            let normalRange = Swift.max(hrvStdDev, 1.0)
            let hrvScore = Int(Swift.max(0, Swift.min(100, 50 + (hrvValue - hrvMean) / normalRange * 20)))

            let rhrScore: Int
            if let rhrValue = rhrByDay[day], rhrMean > 0 {
                let delta = rhrValue - rhrMean
                rhrScore = Int(Swift.max(0, Swift.min(100, 70 - delta * 5)))
            } else {
                rhrScore = 50
            }

            let sleepScore: Int
            if let sleepHours = sleepByDay[day] {
                sleepScore = Int(Swift.max(0, Swift.min(100, sleepHours / 8.0 * 80)))
            } else {
                sleepScore = 50
            }

            let score = Double(hrvScore) * ApproxWeights.hrv
                      + Double(rhrScore) * ApproxWeights.rhr
                      + Double(sleepScore) * ApproxWeights.sleep
            guard score.isFinite && !score.isNaN else { return nil }

            return ChartDataPoint(date: day, value: Swift.max(0, Swift.min(100, score)))
        }
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
