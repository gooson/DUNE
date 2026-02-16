import Foundation
import Observation
import OSLog

/// ViewModel for MetricDetailView — loads period-based chart data and summary stats.
/// Uses `import Observation` only (no SwiftUI per layer rules).
@Observable
@MainActor
final class MetricDetailViewModel {
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
    var rangeData: [RangeDataPoint] = []
    var stackedData: [StackedDataPoint] = []
    var summaryStats: MetricSummary?
    var highlights: [Highlight] = []
    var isLoading = false
    var errorMessage: String?

    /// Raw workouts for the current period (stored for scroll-based totals recalculation).
    private var loadedWorkouts: [WorkoutSummary] = []

    /// The unit label for the current metric (e.g. "km" for distance-based exercises).
    /// Defaults to the category's standard unit; overridden for distance-based workout types.
    var metricUnit: String = ""

    private(set) var category: HealthMetric.Category = .hrv
    private(set) var currentValue: Double = 0
    private(set) var lastUpdated: Date?
    private(set) var workoutTypeName: String?

    private let hrvService: HRVQuerying
    private let sleepService: SleepQuerying
    private let stepsService: StepsQuerying
    private let workoutService: WorkoutQuerying
    private let bodyService: BodyCompositionQuerying

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

    func configure(
        category: HealthMetric.Category,
        currentValue: Double,
        lastUpdated: Date?,
        workoutTypeName: String? = nil,
        metricUnit: String? = nil
    ) {
        self.category = category
        self.currentValue = currentValue
        self.lastUpdated = lastUpdated
        self.workoutTypeName = workoutTypeName
        self.metricUnit = metricUnit ?? ""
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

    // MARK: - Exercise Totals (scroll-reactive)

    /// Exercise totals for the currently visible scroll range.
    /// Recalculates automatically when scrollPosition changes.
    var exerciseTotals: ExerciseTotals? {
        guard category == .exercise, !loadedWorkouts.isEmpty else { return nil }
        let visibleEnd = scrollPosition.addingTimeInterval(selectedPeriod.visibleDomainSeconds)
        let visible = loadedWorkouts.filter { $0.date >= scrollPosition && $0.date <= visibleEnd }
        return buildExerciseTotals(from: visible)
    }

    // MARK: - Scroll Position

    /// Label showing the currently visible date range, like Health app.
    var visibleRangeLabel: String {
        selectedPeriod.visibleRangeLabel(from: scrollPosition)
    }

    /// Trend line data points (linear regression) for the visible chart data.
    /// Returns nil if fewer than 3 data points in the visible range.
    var trendLineData: [ChartDataPoint]? {
        guard showTrendLine else { return nil }
        return Self.computeTrendLine(from: chartData, period: selectedPeriod, scrollPosition: scrollPosition)
    }

    /// Resets scroll position to show the current period (latest data at the right edge).
    private func resetScrollPosition() {
        let range = selectedPeriod.dateRange(offset: 0)
        scrollPosition = range.start
    }

    // MARK: - Extended Range

    /// Returns the extended date range including scroll buffer periods for historical scrolling.
    private var extendedRange: (start: Date, end: Date) {
        let currentRange = selectedPeriod.dateRange(offset: 0)
        let bufferRange = selectedPeriod.dateRange(offset: -selectedPeriod.scrollBufferPeriods)
        return (start: bufferRange.start, end: currentRange.end)
    }

    // MARK: - Private Reload Trigger

    private func triggerReload() {
        Task { await loadData() }
    }

    // MARK: - HRV

    private func loadHRVData() async throws {
        let range = extendedRange
        let interval = HealthDataAggregator.intervalComponents(for: selectedPeriod)

        async let currentData = hrvService.fetchHRVCollection(
            start: range.start, end: range.end, interval: interval
        )
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)
        async let prevData = hrvService.fetchHRVCollection(
            start: prevRange.start, end: prevRange.end, interval: interval
        )

        let current = try await currentData
        let previous = try await prevData

        chartData = current.map { ChartDataPoint(date: $0.date, value: $0.average) }
        summaryStats = HealthDataAggregator.computeSummary(
            from: currentPeriodValues(),
            previousPeriodValues: previous.map(\.average)
        )
    }

    // MARK: - RHR

    private func loadRHRData() async throws {
        let range = extendedRange
        let interval = HealthDataAggregator.intervalComponents(for: selectedPeriod)

        async let currentData = hrvService.fetchRHRCollection(
            start: range.start, end: range.end, interval: interval
        )
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)
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
            from: currentPeriodValues(),
            previousPeriodValues: previous.map(\.average)
        )
    }

    // MARK: - Sleep

    private func loadSleepData() async throws {
        let range = extendedRange

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
            let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)
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

            // Summary uses actual data only (before gap fill)
            summaryStats = HealthDataAggregator.computeSummary(
                from: currentPeriodValues(from: current.map(\.totalMinutes), dates: current.map(\.date)),
                previousPeriodValues: previous.map(\.totalMinutes)
            )

            // Fill date gaps so chart shows all dates (like Health app)
            chartData = HealthDataAggregator.fillDateGaps(
                chartData, period: selectedPeriod, start: range.start, end: range.end
            )
        }
    }

    // MARK: - Steps

    private func loadStepsData() async throws {
        let range = extendedRange
        let interval = HealthDataAggregator.intervalComponents(for: selectedPeriod)

        async let currentData = stepsService.fetchStepsCollection(
            start: range.start, end: range.end, interval: interval
        )
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)
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

        // Summary uses actual data only (before gap fill)
        summaryStats = HealthDataAggregator.computeSummary(
            from: currentPeriodValues(),
            previousPeriodValues: previous.map(\.sum)
        )

        // Fill date gaps so chart shows all dates (like Health app)
        chartData = HealthDataAggregator.fillDateGaps(
            chartData, period: selectedPeriod, start: range.start, end: range.end
        )
    }

    // MARK: - Exercise

    private func loadExerciseData() async throws {
        let range = extendedRange

        async let currentWorkouts = workoutService.fetchWorkouts(start: range.start, end: range.end)
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)
        async let prevWorkouts = workoutService.fetchWorkouts(start: prevRange.start, end: prevRange.end)

        var current = try await currentWorkouts
        var previous = try await prevWorkouts

        // Filter by workout type if viewing a specific type
        if let typeName = workoutTypeName {
            current = current.filter { $0.type == typeName }
            previous = previous.filter { $0.type == typeName }
        }

        // Group by day — distance (km) for distance-based types, duration (min) otherwise
        let currentPoints = groupWorkoutsByDay(current)
        let previousPoints = groupWorkoutsByDay(previous)

        // Update metric unit based on actual chart data type
        let useDistance = isDistanceBased && current.contains(where: { $0.distance != nil && $0.distance! > 0 })
        metricUnit = useDistance ? "km" : "min"

        // Aggregate for longer periods
        if selectedPeriod == .sixMonths || selectedPeriod == .year {
            chartData = HealthDataAggregator.aggregateBySum(
                currentPoints, unit: selectedPeriod.aggregationUnit
            )
        } else {
            chartData = currentPoints
        }

        // Summary uses actual data only (before gap fill)
        summaryStats = HealthDataAggregator.computeSummary(
            from: currentPeriodValues(),
            previousPeriodValues: previousPoints.map(\.value)
        )

        // Fill date gaps so chart shows all dates (like Health app)
        chartData = HealthDataAggregator.fillDateGaps(
            chartData, period: selectedPeriod, start: range.start, end: range.end
        )

        // Store workouts for scroll-reactive totals (computed property uses scrollPosition)
        loadedWorkouts = current
    }

    // MARK: - Weight

    private func loadWeightData() async throws {
        let range = extendedRange

        async let currentSamples = bodyService.fetchWeight(start: range.start, end: range.end)
        let prevRange = HealthDataAggregator.previousPeriodRange(for: selectedPeriod, offset: 0)
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
            from: currentPeriodValues(),
            previousPeriodValues: previous.map(\.value)
        )
    }

    // MARK: - Helpers

    /// Extracts values only from the current (offset=0) period for summary stats.
    private func currentPeriodValues() -> [Double] {
        let currentRange = selectedPeriod.dateRange(offset: 0)
        return chartData
            .filter { $0.date >= currentRange.start && $0.date <= currentRange.end }
            .map(\.value)
    }

    /// Extracts values from the current period using raw values and dates (for sleep).
    private func currentPeriodValues(from values: [Double], dates: [Date]) -> [Double] {
        let currentRange = selectedPeriod.dateRange(offset: 0)
        return zip(values, dates)
            .filter { $0.1 >= currentRange.start && $0.1 <= currentRange.end }
            .map(\.0)
    }

    /// Groups workouts by day, summing either distance (km) or duration (min) based on workout type.
    private func groupWorkoutsByDay(_ workouts: [WorkoutSummary]) -> [ChartDataPoint] {
        let calendar = Calendar.current
        let useDistance = isDistanceBased && workouts.contains(where: { $0.distance != nil && $0.distance! > 0 })

        var dailyValues: [Date: Double] = [:]
        for workout in workouts {
            let dayStart = calendar.startOfDay(for: workout.date)
            if useDistance {
                let km = (workout.distance ?? 0) / 1000.0
                dailyValues[dayStart, default: 0] += km
            } else {
                dailyValues[dayStart, default: 0] += workout.duration / 60.0
            }
        }
        return dailyValues
            .map { ChartDataPoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    /// Whether the current workout type is distance-based (running, cycling, walking, hiking, swimming).
    private var isDistanceBased: Bool {
        guard let typeName = workoutTypeName else { return false }
        switch typeName.lowercased() {
        case "running", "cycling", "walking", "hiking", "swimming":
            return true
        default:
            return false
        }
    }

    private func buildExerciseTotals(from workouts: [WorkoutSummary]) -> ExerciseTotals? {
        guard !workouts.isEmpty else { return nil }
        let totalDuration = workouts.map(\.duration).reduce(0, +)
        let totalCalories = workouts.compactMap(\.calories).reduce(0, +)
        let totalDistance = workouts.compactMap(\.distance).reduce(0, +)
        return ExerciseTotals(
            workoutCount: workouts.count,
            totalDuration: totalDuration,
            totalCalories: totalCalories > 0 ? totalCalories : nil,
            totalDistanceMeters: totalDistance > 0 ? totalDistance : nil
        )
    }

    // MARK: - Highlights

    private func buildHighlights() {
        let currentValues = currentPeriodChartData()
        guard !currentValues.isEmpty else {
            highlights = []
            return
        }

        var result: [Highlight] = []

        // Highest value
        if let maxPoint = currentValues.max(by: { $0.value < $1.value }) {
            result.append(Highlight(
                type: .high,
                value: maxPoint.value,
                date: maxPoint.date,
                label: "Highest"
            ))
        }

        // Lowest value
        if let minPoint = currentValues.min(by: { $0.value < $1.value }) {
            result.append(Highlight(
                type: .low,
                value: minPoint.value,
                date: minPoint.date,
                label: "Lowest"
            ))
        }

        // Trend direction (simple: compare first half vs second half average)
        if currentValues.count >= 4 {
            let mid = currentValues.count / 2
            let firstHalf = currentValues[..<mid].map(\.value)
            let secondHalf = currentValues[mid...].map(\.value)
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

    /// Returns chart data filtered to the current period only (for highlights).
    private func currentPeriodChartData() -> [ChartDataPoint] {
        let currentRange = selectedPeriod.dateRange(offset: 0)
        return chartData.filter { $0.date >= currentRange.start && $0.date <= currentRange.end }
    }

    // MARK: - Trend Line (Linear Regression)

    /// Computes a linear regression trend line for data visible in the current scroll window.
    /// Returns nil if fewer than 3 points or if the regression is degenerate.
    static func computeTrendLine(
        from data: [ChartDataPoint],
        period: TimePeriod,
        scrollPosition: Date
    ) -> [ChartDataPoint]? {
        let visibleEnd = scrollPosition.addingTimeInterval(period.visibleDomainSeconds)
        let visible = data.filter { $0.date >= scrollPosition && $0.date <= visibleEnd }
        guard visible.count >= 3 else { return nil }

        // Linear regression: y = mx + b
        let n = Double(visible.count)
        let referenceTime = visible.first!.date.timeIntervalSince1970

        let xs = visible.map { $0.date.timeIntervalSince1970 - referenceTime }
        let ys = visible.map(\.value)

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }

        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 1e-10 else { return nil }

        let m = (n * sumXY - sumX * sumY) / denominator
        let b = (sumY - m * sumX) / n

        // Generate two end points for the trend line
        guard let firstDate = visible.first?.date,
              let lastDate = visible.last?.date else { return nil }

        let x1 = firstDate.timeIntervalSince1970 - referenceTime
        let x2 = lastDate.timeIntervalSince1970 - referenceTime
        let y1 = m * x1 + b
        let y2 = m * x2 + b

        guard !y1.isNaN && !y1.isInfinite && !y2.isNaN && !y2.isInfinite else { return nil }

        return [
            ChartDataPoint(date: firstDate, value: y1),
            ChartDataPoint(date: lastDate, value: y2),
        ]
    }
}
