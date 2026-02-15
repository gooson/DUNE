import Foundation
import Observation
import OSLog

/// ViewModel for ConditionScoreDetailView — loads period-based daily scores.
/// Uses CalculateConditionScoreUseCase to compute daily scores from HRV samples.
@Observable
@MainActor
final class ConditionScoreDetailViewModel {
    var selectedPeriod: TimePeriod = .week {
        didSet { if oldValue != selectedPeriod { periodOffset = 0; triggerReload() } }
    }
    var periodOffset: Int = 0 {
        didSet { if oldValue != periodOffset { triggerReload() } }
    }
    var chartData: [ChartDataPoint] = []
    var summaryStats: MetricSummary?
    var highlights: [Highlight] = []
    var isLoading = false
    var errorMessage: String?

    var canGoForward: Bool { periodOffset < 0 }

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
            buildHighlights()
        } catch {
            AppLogger.ui.error("ConditionScoreDetail load failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Private

    private func triggerReload() {
        Task { await loadData() }
    }

    private func loadScoreData() async throws {
        let range = selectedPeriod.dateRange(offset: periodOffset)

        // Fetch all HRV samples for the period
        let calendar = Calendar.current
        let daysInRange = max(1, calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 7)

        async let currentSamplesTask = hrvService.fetchHRVSamples(days: daysInRange + 7)

        // Previous period for comparison
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: periodOffset)
        let prevDays = max(1, calendar.dateComponents([.day], from: prevRange.start, to: prevRange.end).day ?? 7)
        async let prevSamplesTask = hrvService.fetchHRVSamples(days: daysInRange + prevDays + 7)

        let allSamples = try await currentSamplesTask
        let allSamplesForPrev = try await prevSamplesTask

        // Compute daily scores for the current period
        let currentScores = computeDailyScores(
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

        chartData = currentScores

        // Aggregate for longer periods
        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            chartData = HealthDataAggregator.aggregateByAverage(
                chartData, unit: selectedPeriod.aggregationUnit
            )
        }

        summaryStats = HealthDataAggregator.computeSummary(
            from: currentScores.map(\.value),
            previousPeriodValues: previousScores.isEmpty ? nil : previousScores.map(\.value)
        )
    }

    /// Computes daily condition scores within the given range.
    /// For each day, uses all HRV samples up to (and including) that day to calculate a score.
    private func computeDailyScores(
        samples: [HRVSample],
        range: (start: Date, end: Date),
        calendar: Calendar
    ) -> [ChartDataPoint] {
        var results: [ChartDataPoint] = []
        let startDay = calendar.startOfDay(for: range.start)
        let endDay = calendar.startOfDay(for: range.end)

        var current = startDay
        while current <= endDay {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: current) else { break }

            // Include all samples up to the end of this day for baseline calculation
            let relevantSamples = samples.filter { $0.date < nextDay }

            let input = CalculateConditionScoreUseCase.Input(
                hrvSamples: relevantSamples,
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
        guard !chartData.isEmpty else {
            highlights = []
            return
        }

        var result: [Highlight] = []

        if let maxPoint = chartData.max(by: { $0.value < $1.value }) {
            result.append(Highlight(
                type: .high,
                value: maxPoint.value,
                date: maxPoint.date,
                label: "Best day"
            ))
        }

        if let minPoint = chartData.min(by: { $0.value < $1.value }) {
            result.append(Highlight(
                type: .low,
                value: minPoint.value,
                date: minPoint.date,
                label: "Lowest day"
            ))
        }

        // Trend
        if chartData.count >= 4 {
            let mid = chartData.count / 2
            let firstHalf = chartData[..<mid].map(\.value)
            let secondHalf = chartData[mid...].map(\.value)
            let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
            let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)

            if firstAvg > 0 {
                let changePercent = ((secondAvg - firstAvg) / firstAvg) * 100
                if abs(changePercent) >= 3 {
                    let direction = changePercent > 0 ? "Trending up" : "Trending down"
                    result.append(Highlight(
                        type: .trend,
                        value: changePercent,
                        date: Date(),
                        label: direction
                    ))
                }
            }
        }

        highlights = result
    }
}
