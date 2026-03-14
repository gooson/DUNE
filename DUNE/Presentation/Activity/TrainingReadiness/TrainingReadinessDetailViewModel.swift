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
    var showTrendLine: Bool = false

    var readiness: TrainingReadiness?
    var chartData: [ChartDataPoint] = []
    var hrvTrend: [ChartDataPoint] = []
    var rhrTrend: [ChartDataPoint] = []
    var sleepTrend: [ChartDataPoint] = []
    var summaryStats: MetricSummary?
    var highlights: [Highlight] = []
    var isLoading = false
    var errorMessage: String?

    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying

    init(
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
    }

    func configure(readiness: TrainingReadiness?) {
        self.readiness = readiness
        resetScrollPosition()
    }

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            try await loadReadinessData()
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            buildHighlights()
        } catch {
            AppLogger.ui.error("ReadinessDetail load failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Scroll Position

    var visibleRangeLabel: String {
        selectedPeriod.visibleRangeLabel(from: scrollPosition)
    }

    var trendLineData: [ChartDataPoint]? {
        guard showTrendLine else { return nil }
        return MetricDetailViewModel.computeTrendLine(
            from: chartData, period: selectedPeriod, scrollPosition: scrollPosition
        )
    }

    var scrollDomain: ClosedRange<Date> {
        let range = extendedRange
        let upperBound = selectedPeriod.scrollDomainUpperBound(referenceDate: range.end)
        return range.start...max(range.end, upperBound)
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

    // MARK: - Private

    private var reloadTask: Task<Void, Never>?

    private func triggerReload() {
        reloadTask?.cancel()
        reloadTask = Task { await loadData() }
    }

    private func loadReadinessData() async throws {
        let calendar = Calendar.current
        let range = extendedRange
        let daysInRange = max(1, calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 14)

        // Fetch HRV, RHR, and Sleep in parallel
        async let hrvTask = hrvService.fetchHRVSamples(days: daysInRange)
        async let rhrTask = hrvService.fetchRHRCollection(
            start: range.start,
            end: range.end,
            interval: DateComponents(day: 1)
        )
        async let sleepTask = sleepService.fetchDailySleepDurations(
            start: range.start,
            end: range.end
        )

        // Previous period for comparison
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)
        let prevDays = max(1, calendar.dateComponents([.day], from: prevRange.start, to: prevRange.end).day ?? 14)
        async let prevHRVTask = hrvService.fetchHRVSamples(
            days: daysInRange + prevDays
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

        let (allHRV, allRHR, allSleep) = try await (hrvTask, rhrTask, sleepTask)
        let (prevHRV, prevRHR, prevSleep) = try await (prevHRVTask, prevRHRTask, prevSleepTask)

        // Build sub-score arrays for current period
        let currentPeriodRange = selectedPeriod.dateRange(offset: 0)
        let currentHRV = buildHRVDailyAverages(from: allHRV, start: range.start, end: range.end, calendar: calendar)
        let currentRHR = allRHR
            .filter { $0.average > 0 && $0.average.isFinite }
            .map { ChartDataPoint(date: $0.date, value: $0.average) }
            .sorted { $0.date < $1.date }
        let currentSleep = allSleep
            .map { ChartDataPoint(date: $0.date, value: Swift.max(0, Swift.min($0.totalMinutes / 60.0, 24))) }
            .sorted { $0.date < $1.date }

        hrvTrend = currentHRV.filter { $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end }
        rhrTrend = currentRHR.filter { $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end }
        sleepTrend = currentSleep.filter { $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end }

        // Build readiness trend from sub-scores (full extended range for chart scroll)
        let allScores = buildReadinessTrend(hrv: currentHRV, rhr: currentRHR, sleep: currentSleep)
        chartData = allScores

        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            chartData = HealthDataAggregator.aggregateByAverage(
                chartData, unit: selectedPeriod.aggregationUnit
            )
        }

        // Previous period scores for comparison
        let prevHRVDaily = buildHRVDailyAverages(from: prevHRV, start: prevRange.start, end: prevRange.end, calendar: calendar)
        let prevRHRDaily = prevRHR
            .filter { $0.average > 0 && $0.average.isFinite }
            .map { ChartDataPoint(date: $0.date, value: $0.average) }
        let prevSleepDaily = prevSleep
            .map { ChartDataPoint(date: $0.date, value: Swift.max(0, Swift.min($0.totalMinutes / 60.0, 24))) }
        let previousScores = buildReadinessTrend(hrv: prevHRVDaily, rhr: prevRHRDaily, sleep: prevSleepDaily)

        // Summary stats from current period only
        let currentPeriodScores = allScores.filter {
            $0.date >= currentPeriodRange.start && $0.date <= currentPeriodRange.end
        }
        summaryStats = HealthDataAggregator.computeSummary(
            from: currentPeriodScores.map(\.value),
            previousPeriodValues: previousScores.isEmpty ? nil : previousScores.map(\.value)
        )
    }

    // MARK: - HRV Daily Averages

    private func buildHRVDailyAverages(
        from samples: [HRVSample],
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> [ChartDataPoint] {
        let filtered = samples.filter { $0.date >= start && $0.date <= end }
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return grouped.compactMap { day, daySamples in
            let values = daySamples.map(\.value)
            guard !values.isEmpty else { return nil }
            let avg = values.reduce(0, +) / Double(values.count)
            guard avg.isFinite else { return nil }
            return ChartDataPoint(date: day, value: avg)
        }.sorted { $0.date < $1.date }
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
