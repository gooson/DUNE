import Foundation
import Observation
import OSLog

/// ViewModel for MetricDetailView — loads period-based chart data and summary stats.
/// Uses `import Observation` only (no SwiftUI per layer rules).
@Observable
@MainActor
final class MetricDetailViewModel {
    var selectedPeriod: TimePeriod = .week {
        didSet { if oldValue != selectedPeriod { periodOffset = 0; triggerReload() } }
    }
    var periodOffset: Int = 0 {
        didSet { if oldValue != periodOffset { triggerReload() } }
    }
    var chartData: [ChartDataPoint] = []
    var rangeData: [RangeDataPoint] = []
    var stackedData: [StackedDataPoint] = []
    var summaryStats: MetricSummary?
    var highlights: [Highlight] = []
    var isLoading = false
    var errorMessage: String?

    var canGoForward: Bool { periodOffset < 0 }

    private(set) var category: HealthMetric.Category = .hrv
    private(set) var currentValue: Double = 0
    private(set) var lastUpdated: Date?

    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying
    private let stepsService: StepsQuerying
    private let workoutService: WorkoutQuerying
    private let bodyService: BodyCompositionQuerying

    private var needsReload = false

    init(
        hrvService: HRVQuerying? = nil,
        sleepService: SleepQuerying? = nil,
        stepsService: StepsQuerying? = nil,
        workoutService: WorkoutQuerying? = nil,
        bodyService: BodyCompositionQuerying? = nil,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.hrvService = hrvService ?? HRVQueryService(manager: healthKitManager)
        self.sleepService = sleepService ?? SleepQueryService(manager: healthKitManager)
        self.stepsService = stepsService ?? StepsQueryService(manager: healthKitManager)
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
        self.bodyService = bodyService ?? BodyCompositionQueryService(manager: healthKitManager)
    }

    func configure(category: HealthMetric.Category, currentValue: Double, lastUpdated: Date?) {
        self.category = category
        self.currentValue = currentValue
        self.lastUpdated = lastUpdated
    }

    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            switch category {
            case .hrv:      try await loadHRVData()
            case .rhr:      try await loadRHRData()
            case .sleep:    try await loadSleepData()
            case .steps:    try await loadStepsData()
            case .exercise: try await loadExerciseData()
            case .weight:   try await loadWeightData()
            }
            buildHighlights()
        } catch {
            AppLogger.ui.error("MetricDetail load failed for \(self.category.rawValue): \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Private Reload Trigger

    private func triggerReload() {
        needsReload = true
        Task { await loadData() }
    }

    // MARK: - HRV

    private func loadHRVData() async throws {
        let range = selectedPeriod.dateRange(offset: periodOffset)
        let interval = HealthDataAggregator.intervalComponents(for: selectedPeriod)

        async let currentData = hrvService.fetchHRVCollection(
            start: range.start, end: range.end, interval: interval
        )
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: periodOffset)
        async let prevData = hrvService.fetchHRVCollection(
            start: prevRange.start, end: prevRange.end, interval: interval
        )

        let current = try await currentData
        let previous = try await prevData

        chartData = current.map { ChartDataPoint(date: $0.date, value: $0.average) }
        summaryStats = HealthDataAggregator.computeSummary(
            from: chartData.map(\.value),
            previousPeriodValues: previous.map(\.average)
        )
    }

    // MARK: - RHR

    private func loadRHRData() async throws {
        let range = selectedPeriod.dateRange(offset: periodOffset)
        let interval = HealthDataAggregator.intervalComponents(for: selectedPeriod)

        async let currentData = hrvService.fetchRHRCollection(
            start: range.start, end: range.end, interval: interval
        )
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: periodOffset)
        async let prevData = hrvService.fetchRHRCollection(
            start: prevRange.start, end: prevRange.end, interval: interval
        )

        let current = try await currentData
        let previous = try await prevData

        rangeData = current.map {
            RangeDataPoint(date: $0.date, min: $0.min, max: $0.max, average: $0.average)
        }
        chartData = current.map { ChartDataPoint(date: $0.date, value: $0.average) }

        // Aggregate range data for longer periods
        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            rangeData = HealthDataAggregator.aggregateRangeData(
                rangeData, unit: selectedPeriod.aggregationUnit
            )
        }

        summaryStats = HealthDataAggregator.computeSummary(
            from: chartData.map(\.value),
            previousPeriodValues: previous.map(\.average)
        )
    }

    // MARK: - Sleep

    private func loadSleepData() async throws {
        let range = selectedPeriod.dateRange(offset: periodOffset)

        if selectedPeriod == .day {
            // Day mode: show raw sleep stages
            let stages = try await sleepService.fetchSleepStages(for: Date())
            let sleepStages = stages.filter { $0.stage != .awake }
            let totalMinutes = sleepStages.reduce(0.0) { $0 + $1.duration } / 60.0
            chartData = [ChartDataPoint(date: Date(), value: totalMinutes)]
            summaryStats = HealthDataAggregator.computeSummary(from: [totalMinutes])
        } else {
            // Week+ mode: daily sleep with stage breakdown
            async let currentSleep = sleepService.fetchDailySleepDurations(
                start: range.start, end: range.end
            )
            let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: periodOffset)
            async let prevSleep = sleepService.fetchDailySleepDurations(
                start: prevRange.start, end: prevRange.end
            )

            let current = try await currentSleep
            let previous = try await prevSleep

            // Build chart data (total minutes)
            chartData = current.map {
                ChartDataPoint(date: $0.date, value: $0.totalMinutes)
            }

            // Build stacked data for stage breakdown
            stackedData = current.map { day in
                let segments: [StackedDataPoint.Segment] = [
                    .init(category: "Deep", value: day.stageBreakdown[.deep] ?? 0),
                    .init(category: "Core", value: day.stageBreakdown[.core] ?? 0),
                    .init(category: "REM", value: day.stageBreakdown[.rem] ?? 0),
                ]
                return StackedDataPoint(
                    id: day.date.ISO8601Format(),
                    date: day.date,
                    segments: segments
                )
            }

            // Aggregate for longer periods
            if selectedPeriod == .sixMonths || selectedPeriod == .year {
                chartData = HealthDataAggregator.aggregateByAverage(
                    chartData, unit: selectedPeriod.aggregationUnit
                )
            }

            summaryStats = HealthDataAggregator.computeSummary(
                from: current.map(\.totalMinutes),
                previousPeriodValues: previous.map(\.totalMinutes)
            )
        }
    }

    // MARK: - Steps

    private func loadStepsData() async throws {
        let range = selectedPeriod.dateRange(offset: periodOffset)
        let interval = HealthDataAggregator.intervalComponents(for: selectedPeriod)

        async let currentData = stepsService.fetchStepsCollection(
            start: range.start, end: range.end, interval: interval
        )
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: periodOffset)
        async let prevData = stepsService.fetchStepsCollection(
            start: prevRange.start, end: prevRange.end, interval: interval
        )

        let current = try await currentData
        let previous = try await prevData

        let raw = current.map { ChartDataPoint(date: $0.date, value: $0.sum) }

        // For 6M/Y, aggregate sums by week/month
        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            chartData = HealthDataAggregator.aggregateBySum(
                raw, unit: selectedPeriod.aggregationUnit
            )
        } else {
            chartData = raw
        }

        summaryStats = HealthDataAggregator.computeSummary(
            from: raw.map(\.value),
            previousPeriodValues: previous.map(\.sum)
        )
    }

    // MARK: - Exercise

    private func loadExerciseData() async throws {
        let range = selectedPeriod.dateRange(offset: periodOffset)

        async let currentWorkouts = workoutService.fetchWorkouts(start: range.start, end: range.end)
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: periodOffset)
        async let prevWorkouts = workoutService.fetchWorkouts(start: prevRange.start, end: prevRange.end)

        let current = try await currentWorkouts
        let previous = try await prevWorkouts

        // Group by day and sum duration
        let currentPoints = groupWorkoutsByDay(current)
        let previousPoints = groupWorkoutsByDay(previous)

        // Aggregate for longer periods
        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            chartData = HealthDataAggregator.aggregateBySum(
                currentPoints, unit: selectedPeriod.aggregationUnit
            )
        } else {
            chartData = currentPoints
        }

        summaryStats = HealthDataAggregator.computeSummary(
            from: currentPoints.map(\.value),
            previousPeriodValues: previousPoints.map(\.value)
        )
    }

    // MARK: - Weight

    private func loadWeightData() async throws {
        let range = selectedPeriod.dateRange(offset: periodOffset)

        async let currentSamples = bodyService.fetchWeight(start: range.start, end: range.end)
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: periodOffset)
        async let prevSamples = bodyService.fetchWeight(start: prevRange.start, end: prevRange.end)

        let current = try await currentSamples
        let previous = try await prevSamples

        let raw = current
            .map { ChartDataPoint(date: $0.date, value: $0.value) }
            .sorted { $0.date < $1.date }

        // Weight uses average aggregation for longer periods
        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            chartData = HealthDataAggregator.aggregateByAverage(
                raw, unit: selectedPeriod.aggregationUnit
            )
        } else {
            chartData = raw
        }

        summaryStats = HealthDataAggregator.computeSummary(
            from: raw.map(\.value),
            previousPeriodValues: previous.map(\.value)
        )
    }

    // MARK: - Helpers

    private func groupWorkoutsByDay(_ workouts: [WorkoutSummary]) -> [ChartDataPoint] {
        let calendar = Calendar.current
        var dailyMinutes: [Date: Double] = [:]
        for workout in workouts {
            let dayStart = calendar.startOfDay(for: workout.date)
            dailyMinutes[dayStart, default: 0] += workout.duration / 60.0
        }
        return dailyMinutes
            .map { ChartDataPoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Highlights

    private func buildHighlights() {
        guard !chartData.isEmpty else {
            highlights = []
            return
        }

        var result: [Highlight] = []

        // Highest value
        if let maxPoint = chartData.max(by: { $0.value < $1.value }) {
            result.append(Highlight(
                type: .high,
                value: maxPoint.value,
                date: maxPoint.date,
                label: "Highest"
            ))
        }

        // Lowest value
        if let minPoint = chartData.min(by: { $0.value < $1.value }) {
            result.append(Highlight(
                type: .low,
                value: minPoint.value,
                date: minPoint.date,
                label: "Lowest"
            ))
        }

        // Trend direction (simple: compare first half vs second half average)
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
