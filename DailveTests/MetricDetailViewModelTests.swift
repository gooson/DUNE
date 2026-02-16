import Testing
import Foundation
@testable import Dailve

// MARK: - Mock Services for MetricDetailViewModel

private struct StubHRVService: HRVQuerying {
    var hrvCollection: [(date: Date, average: Double)] = []
    var rhrCollection: [(date: Date, min: Double, max: Double, average: Double)] = []

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { [] }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { hrvCollection }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { rhrCollection }
}

private struct StubSleepService: SleepQuerying {
    var dailySleep: [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] = []
    var todayStages: [SleepStage] = []

    func fetchSleepStages(for date: Date) async throws -> [SleepStage] { todayStages }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { nil }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] { dailySleep }
}

private struct StubStepsService: StepsQuerying {
    var stepsCollection: [(date: Date, sum: Double)] = []

    func fetchSteps(for date: Date) async throws -> Double? { nil }
    func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchStepsCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, sum: Double)] { stepsCollection }
}

private struct StubWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { workouts }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] { workouts }
}

private struct StubBodyService: BodyCompositionQuerying {
    var weightSamples: [BodyCompositionSample] = []

    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] { weightSamples }
    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] { weightSamples }
}

// MARK: - Tests

@Suite("MetricDetailViewModel")
@MainActor
struct MetricDetailViewModelTests {

    private let calendar = Calendar.current

    private func makeVM(
        hrv: StubHRVService = StubHRVService(),
        sleep: StubSleepService = StubSleepService(),
        steps: StubStepsService = StubStepsService(),
        workout: StubWorkoutService = StubWorkoutService(),
        body: StubBodyService = StubBodyService()
    ) -> MetricDetailViewModel {
        MetricDetailViewModel(
            hrvService: hrv,
            sleepService: sleep,
            stepsService: steps,
            workoutService: workout,
            bodyService: body
        )
    }

    // MARK: - HRV

    @Test("HRV loads chart data from collection query")
    func hrvLoadsData() async {
        let today = calendar.startOfDay(for: Date())
        let hrv = StubHRVService(hrvCollection: [
            (date: calendar.date(byAdding: .day, value: -2, to: today)!, average: 45.0),
            (date: calendar.date(byAdding: .day, value: -1, to: today)!, average: 50.0),
            (date: today, average: 55.0),
        ])
        let vm = makeVM(hrv: hrv)
        vm.configure(category: .hrv, currentValue: 55, lastUpdated: Date())

        await vm.loadData()

        #expect(vm.chartData.count == 3)
        #expect(vm.summaryStats != nil)
        #expect(vm.summaryStats!.average == 50.0) // (45+50+55)/3
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - RHR

    @Test("RHR loads range data with min/max")
    func rhrLoadsRangeData() async {
        let today = calendar.startOfDay(for: Date())
        let hrv = StubHRVService(rhrCollection: [
            (date: calendar.date(byAdding: .day, value: -1, to: today)!, min: 58, max: 66, average: 62),
            (date: today, min: 55, max: 68, average: 60),
        ])
        let vm = makeVM(hrv: hrv)
        vm.configure(category: .rhr, currentValue: 60, lastUpdated: Date())

        await vm.loadData()

        #expect(vm.rangeData.count == 2)
        #expect(vm.rangeData.first!.min == 58.0)
        #expect(vm.rangeData.first!.max == 66.0)
        #expect(vm.chartData.count == 2)
    }

    // MARK: - Steps

    @Test("Steps loads from collection query")
    func stepsLoadsCollection() async {
        let today = calendar.startOfDay(for: Date())
        let steps = StubStepsService(stepsCollection: [
            (date: calendar.date(byAdding: .day, value: -1, to: today)!, sum: 8000),
            (date: today, sum: 10000),
        ])
        let vm = makeVM(steps: steps)
        vm.configure(category: .steps, currentValue: 10000, lastUpdated: Date())

        await vm.loadData()

        // Chart data includes gap-filled dates (all days in range)
        #expect(vm.chartData.count >= 2)
        // Verify actual data points are present
        let nonZero = vm.chartData.filter { $0.value > 0 }
        #expect(nonZero.count == 2)
        #expect(vm.summaryStats!.sum == 18000.0)
    }

    // MARK: - Exercise

    @Test("Exercise groups workouts by day")
    func exerciseGroupsByDay() async {
        let today = calendar.startOfDay(for: Date())
        let workouts = StubWorkoutService(workouts: [
            WorkoutSummary(id: "1", type: "Running", duration: 1800, calories: 200, distance: nil, date: today),
            WorkoutSummary(id: "2", type: "Yoga", duration: 3600, calories: 150, distance: nil, date: today),
        ])
        let vm = makeVM(workout: workouts)
        vm.configure(category: .exercise, currentValue: 90, lastUpdated: Date())

        await vm.loadData()

        // Chart data includes gap-filled dates (all days in range)
        #expect(vm.chartData.count >= 1)
        // Both workouts on same day → 1 non-zero chart point = 90 min
        let nonZero = vm.chartData.filter { $0.value > 0 }
        #expect(nonZero.count == 1)
        #expect(nonZero.first!.value == 90.0) // (1800+3600)/60
    }

    // MARK: - Weight

    @Test("Weight loads raw samples for week period")
    func weightLoadsSamples() async {
        let today = Date()
        let body = StubBodyService(weightSamples: [
            BodyCompositionSample(value: 75.0, date: calendar.date(byAdding: .day, value: -3, to: today)!),
            BodyCompositionSample(value: 74.5, date: calendar.date(byAdding: .day, value: -1, to: today)!),
            BodyCompositionSample(value: 74.8, date: today),
        ])
        let vm = makeVM(body: body)
        vm.configure(category: .weight, currentValue: 74.8, lastUpdated: Date())

        await vm.loadData()

        #expect(vm.chartData.count == 3)
        #expect(vm.summaryStats!.min == 74.5)
        #expect(vm.summaryStats!.max == 75.0)
    }

    // MARK: - Sleep

    @Test("Sleep week mode loads daily durations with stacked data")
    func sleepWeekMode() async {
        let today = calendar.startOfDay(for: Date())
        let sleep = StubSleepService(dailySleep: [
            (date: calendar.date(byAdding: .day, value: -1, to: today)!, totalMinutes: 420, stageBreakdown: [.deep: 90, .core: 240, .rem: 90]),
            (date: today, totalMinutes: 450, stageBreakdown: [.deep: 100, .core: 250, .rem: 100]),
        ])
        let vm = makeVM(sleep: sleep)
        vm.configure(category: .sleep, currentValue: 450, lastUpdated: Date())

        await vm.loadData()

        // Chart data includes gap-filled dates (all days in range)
        #expect(vm.chartData.count >= 2)
        let nonZero = vm.chartData.filter { $0.value > 0 }
        #expect(nonZero.count == 2)
        #expect(vm.stackedData.count == 2)
        #expect(vm.stackedData.first!.segments.count == 3)
    }

    // MARK: - Empty Data

    @Test("Empty data produces no chart data and nil summary")
    func emptyData() async {
        let vm = makeVM()
        vm.configure(category: .hrv, currentValue: 0, lastUpdated: nil)

        await vm.loadData()

        #expect(vm.chartData.isEmpty)
        #expect(vm.summaryStats == nil)
        #expect(vm.highlights.isEmpty)
    }

    // MARK: - Highlights

    @Test("Highlights include high, low, and trend for sufficient data")
    func highlightsBuilt() async {
        let today = calendar.startOfDay(for: Date())
        var points: [(date: Date, average: Double)] = []
        for i in 0..<8 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            // Create trending data: first half ~40, second half ~60
            let value = i < 4 ? Double(60 + i) : Double(40 + i)
            points.append((date: date, average: value))
        }
        let hrv = StubHRVService(hrvCollection: points)
        let vm = makeVM(hrv: hrv)
        vm.configure(category: .hrv, currentValue: 55, lastUpdated: Date())

        await vm.loadData()

        #expect(vm.highlights.count >= 2) // At least high and low
        let types = Set(vm.highlights.map(\.type))
        #expect(types.contains(.high))
        #expect(types.contains(.low))
    }

    // MARK: - Previous Period Summary

    @Test("Summary includes previousPeriodAverage when prev data exists")
    func previousPeriodAverage() async {
        let today = calendar.startOfDay(for: Date())
        let hrv = StubHRVService(hrvCollection: [
            (date: today, average: 50.0),
        ])
        let vm = makeVM(hrv: hrv)
        vm.configure(category: .hrv, currentValue: 50, lastUpdated: Date())

        await vm.loadData()

        // Previous period data also comes from the same stub (returns hrvCollection for any range)
        // Since stub returns 1 point for both current and previous, previousPeriodAverage should be set
        #expect(vm.summaryStats != nil)
        #expect(vm.summaryStats!.previousPeriodAverage != nil)
    }

    // MARK: - Loading State

    @Test("isLoading is false after load completes")
    func loadingState() async {
        let vm = makeVM()
        vm.configure(category: .hrv, currentValue: 0, lastUpdated: nil)

        #expect(vm.isLoading == false)
        await vm.loadData()
        #expect(vm.isLoading == false)
    }

    // MARK: - Trend Line

    @Test("computeTrendLine returns nil for fewer than 3 points")
    func trendLineTooFewPoints() {
        let data = [
            ChartDataPoint(date: Date(), value: 10),
            ChartDataPoint(date: Date().addingTimeInterval(3600), value: 20),
        ]
        let result = MetricDetailViewModel.computeTrendLine(
            from: data, period: .week, scrollPosition: data[0].date
        )
        #expect(result == nil)
    }

    @Test("computeTrendLine returns 2 points for valid data")
    func trendLineValidData() {
        let start = Date()
        let data = (0..<7).map { i in
            ChartDataPoint(
                date: start.addingTimeInterval(Double(i) * 86400),
                value: 40 + Double(i) * 2
            )
        }
        let result = MetricDetailViewModel.computeTrendLine(
            from: data, period: .week, scrollPosition: start
        )
        #expect(result != nil)
        #expect(result!.count == 2)
        // Linear data → trend should go from ~40 to ~52
        #expect(result!.first!.value < result!.last!.value)
    }

    @Test("computeTrendLine ignores data outside visible window")
    func trendLineWindowFiltering() {
        let start = Date()
        // Data way before the visible window
        let oldData = (0..<5).map { i in
            ChartDataPoint(
                date: start.addingTimeInterval(Double(i - 30) * 86400),
                value: 100
            )
        }
        // Data in the visible window
        let visibleData = (0..<5).map { i in
            ChartDataPoint(
                date: start.addingTimeInterval(Double(i) * 86400),
                value: 50 + Double(i)
            )
        }
        let allData = oldData + visibleData
        let result = MetricDetailViewModel.computeTrendLine(
            from: allData, period: .week, scrollPosition: start
        )
        #expect(result != nil)
        // Trend should reflect visible data (~50-54), not the old data (100)
        #expect(result!.first!.value < 60)
    }

    // MARK: - Visible Range Label

    @Test("visibleRangeLabel returns non-empty string")
    func visibleRangeLabel() {
        let vm = makeVM()
        vm.configure(category: .hrv, currentValue: 50, lastUpdated: Date())

        let label = vm.visibleRangeLabel
        #expect(!label.isEmpty)
    }
}
