import Foundation
import Observation
import OSLog

/// ViewModel for the Wellness Score detail view.
/// Self-contained: fetches HRV/RHR/Sleep data directly from HealthKit.
/// Supports period selection and produces DotLineChartView-ready data.
@Observable
@MainActor
final class WellnessScoreDetailViewModel {
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

    var wellnessScore: WellnessScore?
    var conditionScore: ConditionScore?
    var bodyScoreDetail: BodyScoreDetail?
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

    init(
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        recalculateScrollDomain()
    }

    func configure(
        wellnessScore: WellnessScore,
        conditionScore: ConditionScore?,
        bodyScoreDetail: BodyScoreDetail?
    ) {
        self.wellnessScore = wellnessScore
        self.conditionScore = conditionScore
        self.bodyScoreDetail = bodyScoreDetail
        resetScrollPosition()
        recalculateScrollDomain()
    }

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        highlights = []

        do {
            try await loadWellnessData()
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            buildHighlights()
            recalculateTrendLine()
        } catch {
            AppLogger.ui.error("WellnessDetail load failed: \(error.localizedDescription)")
            errorMessage = String(localized: "Could not load data.")
        }

        isLoading = false
    }

    // MARK: - Scroll Position

    var visibleRangeLabel: String {
        selectedPeriod.visibleRangeLabel(from: scrollPosition)
    }

    private func resetScrollPosition() {
        let range = selectedPeriod.dateRange(offset: 0)
        scrollPosition = range.start
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

    private func loadWellnessData() async throws {
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

        // Build wellness trend
        let allScores = buildWellnessTrend(hrv: currentHRV, rhr: currentRHR, sleep: currentSleep)
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
        let previousScores = buildWellnessTrend(hrv: prevHRVDaily, rhr: prevRHRDaily, sleep: prevSleepDaily)

        let currentPeriodScores = allScores.filter {
            $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end
        }
        summaryStats = HealthDataAggregator.computeSummary(
            from: currentPeriodScores.map(\.value),
            previousPeriodValues: previousScores.isEmpty ? nil : previousScores.map(\.value)
        )

        recalculateScrollDomain()
    }

    // MARK: - Wellness Trend Approximation

    /// Wellness = Sleep(40%) + Condition(35%) + Body(25%).
    /// Since Body score requires SwiftData (weight trends), we re-normalize
    /// the remaining weights: Sleep 40/(40+35) ≈ 0.53, Condition 35/(40+35) ≈ 0.47.
    private enum ApproxWeights {
        static let sleep: Double = 0.53
        static let condition: Double = 0.47
    }

    private func buildWellnessTrend(
        hrv: [ChartDataPoint],
        rhr: [ChartDataPoint],
        sleep: [ChartDataPoint]
    ) -> [ChartDataPoint] {
        guard !hrv.isEmpty || !sleep.isEmpty else { return [] }

        let calendar = Calendar.current
        let hrvByDay = Dictionary(hrv.map { (calendar.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { _, last in last })
        let rhrByDay = Dictionary(rhr.map { (calendar.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { _, last in last })
        let sleepByDay = Dictionary(sleep.map { (calendar.startOfDay(for: $0.date), $0.value) }, uniquingKeysWith: { _, last in last })

        let hrvValues = hrv.map(\.value)
        let hrvMean = hrvValues.isEmpty ? 0 : hrvValues.reduce(0, +) / Double(hrvValues.count)
        let hrvStdDev: Double = {
            guard !hrvValues.isEmpty else { return 1.0 }
            let variance = hrvValues.map { ($0 - hrvMean) * ($0 - hrvMean) }.reduce(0, +) / Double(hrvValues.count)
            return sqrt(Swift.max(variance, 0.01))
        }()

        let rhrValues = rhr.map(\.value)
        let rhrMean = rhrValues.isEmpty ? 0 : rhrValues.reduce(0, +) / Double(rhrValues.count)

        let allDays = Set(
            hrv.map { calendar.startOfDay(for: $0.date) }
            + sleep.map { calendar.startOfDay(for: $0.date) }
        ).sorted()

        return allDays.compactMap { day in
            var conditionScore: Double = 50 // neutral
            if let hrvValue = hrvByDay[day] {
                let normalRange = Swift.max(hrvStdDev, 1.0)
                conditionScore = Swift.max(0, Swift.min(100, 50 + (hrvValue - hrvMean) / normalRange * 20))

                if let rhrValue = rhrByDay[day], rhrMean > 0 {
                    let rhrDelta = rhrValue - rhrMean
                    let rhrAdjustment = Swift.max(-15, Swift.min(15, -rhrDelta * 3))
                    conditionScore = Swift.max(0, Swift.min(100, conditionScore + rhrAdjustment))
                }
            }

            var sleepScore: Double = 50 // neutral
            if let sleepHours = sleepByDay[day] {
                sleepScore = Swift.max(0, Swift.min(100, sleepHours / 8.0 * 80))
            }

            let score = conditionScore * ApproxWeights.condition + sleepScore * ApproxWeights.sleep
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
