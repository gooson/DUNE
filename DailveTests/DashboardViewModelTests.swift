import Foundation
import Testing
@testable import Dailve

// MARK: - Mock Services

private struct MockHRVService: HRVQuerying {
    var samples: [HRVSample] = []
    var todayRHR: Double?
    var yesterdayRHR: Double?
    var latestRHR: (value: Double, date: Date)?

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { samples }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return todayRHR }
        if calendar.isDateInYesterday(date) { return yesterdayRHR }
        return nil
    }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { latestRHR }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { [] }
}

private struct MockSleepService: SleepQuerying {
    var todayStages: [SleepStage] = []
    var yesterdayStages: [SleepStage] = []
    var latestStages: (stages: [SleepStage], date: Date)?

    func fetchSleepStages(for date: Date) async throws -> [SleepStage] {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return todayStages }
        if calendar.isDateInYesterday(date) { return yesterdayStages }
        return []
    }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { latestStages }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] { [] }
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? { nil }
}

private struct MockWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []
    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { workouts }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] { workouts }
}

private struct MockStepsService: StepsQuerying {
    var todaySteps: Double?
    var yesterdaySteps: Double?
    var latestSteps: (value: Double, date: Date)?

    func fetchSteps(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return todaySteps }
        if calendar.isDateInYesterday(date) { return yesterdaySteps }
        return nil
    }
    func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)? { latestSteps }
    func fetchStepsCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, sum: Double)] { [] }
}

private struct MockBodyService: BodyCompositionQuerying {
    var weightSamples: [BodyCompositionSample] = []
    var latestWeight: (value: Double, date: Date)?
    var todayBMI: Double?
    var latestBMI: (value: Double, date: Date)?
    var bmiSamples: [BodyCompositionSample] = []

    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] { weightSamples }
    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        let calendar = Calendar.current
        return weightSamples.filter {
            $0.date >= calendar.startOfDay(for: start) && $0.date < end
        }
    }
    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)? { latestWeight }
    func fetchBMI(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return todayBMI }
        return nil
    }
    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)? { latestBMI }
    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample] { bmiSamples }
    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
}

// MARK: - Tests

@Suite("DashboardViewModel Fallback")
@MainActor
struct DashboardViewModelTests {

    // MARK: - HRV Fallback

    @Test("HRV shows latest sample even if not today")
    func hrvFallback() async {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let hrv = MockHRVService(
            samples: [HRVSample(value: 45.0, date: twoDaysAgo)],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: nil
        )
        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService()
        )

        await vm.loadData()

        let hrvMetric = vm.sortedMetrics.first { $0.category == .hrv }
        #expect(hrvMetric != nil)
        #expect(hrvMetric?.value == 45.0)
        #expect(hrvMetric?.isHistorical == true)
    }

    // MARK: - RHR Fallback

    @Test("RHR falls back to latest when today is nil")
    func rhrFallback() async {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let hrv = MockHRVService(
            samples: [HRVSample(value: 50.0, date: Date())],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: (value: 62.0, date: threeDaysAgo)
        )
        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService()
        )

        await vm.loadData()

        let rhrMetric = vm.sortedMetrics.first { $0.category == .rhr }
        #expect(rhrMetric != nil)
        #expect(rhrMetric?.value == 62.0)
        #expect(rhrMetric?.isHistorical == true)
    }

    @Test("RHR uses today when available")
    func rhrToday() async {
        let hrv = MockHRVService(
            samples: [HRVSample(value: 50.0, date: Date())],
            todayRHR: 58.0,
            yesterdayRHR: 60.0,
            latestRHR: nil
        )
        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService()
        )

        await vm.loadData()

        let rhrMetric = vm.sortedMetrics.first { $0.category == .rhr }
        #expect(rhrMetric != nil)
        #expect(rhrMetric?.value == 58.0)
        #expect(rhrMetric?.isHistorical == false)
    }

    // MARK: - Sleep Fallback

    @Test("Sleep falls back to latest when today is empty")
    func sleepFallback() async {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let stages = [SleepStage(stage: .deep, duration: 3600, startDate: twoDaysAgo, endDate: twoDaysAgo.addingTimeInterval(3600))]
        let sleep = MockSleepService(
            todayStages: [],
            yesterdayStages: [],
            latestStages: (stages: stages, date: twoDaysAgo)
        )
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: sleep,
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService()
        )

        await vm.loadData()

        let sleepMetric = vm.sortedMetrics.first { $0.category == .sleep }
        #expect(sleepMetric != nil)
        #expect(sleepMetric?.isHistorical == true)
    }

    // MARK: - Steps Fallback

    @Test("Steps falls back to latest when today is nil")
    func stepsFallback() async {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let steps = MockStepsService(
            todaySteps: nil,
            yesterdaySteps: nil,
            latestSteps: (value: 8500, date: yesterday)
        )
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: steps
        )

        await vm.loadData()

        let stepsMetric = vm.sortedMetrics.first { $0.category == .steps }
        #expect(stepsMetric != nil)
        #expect(stepsMetric?.value == 8500)
        #expect(stepsMetric?.isHistorical == true)
    }

    // MARK: - Exercise Fallback

    @Test("Exercise falls back to most recent workout when today is empty")
    func exerciseFallback() async {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let workout = MockWorkoutService(workouts: [
            WorkoutSummary(id: "1", type: "Running", duration: 1800, calories: 200, distance: nil, date: twoDaysAgo)
        ])
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: workout,
            stepsService: MockStepsService()
        )

        await vm.loadData()

        let exerciseMetric = vm.sortedMetrics.first { $0.category == .exercise }
        #expect(exerciseMetric != nil)
        #expect(exerciseMetric?.value == 30.0) // 1800s / 60
        #expect(exerciseMetric?.isHistorical == true)
    }

    // MARK: - Weight Fallback

    @Test("Weight falls back to latest when today is empty")
    func weightFallback() async {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let body = MockBodyService(
            latestWeight: (value: 72.5, date: threeDaysAgo)
        )
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: body
        )

        await vm.loadData()

        let weightMetric = vm.sortedMetrics.first { $0.category == .weight }
        #expect(weightMetric != nil)
        #expect(weightMetric?.value == 72.5)
        #expect(weightMetric?.isHistorical == true)
    }

    // MARK: - BMI Fallback

    @Test("BMI falls back to latest when today is nil")
    func bmiFallback() async {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let body = MockBodyService(
            latestBMI: (value: 23.4, date: twoDaysAgo)
        )
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: body
        )

        await vm.loadData()

        let bmiMetric = vm.sortedMetrics.first { $0.category == .bmi }
        #expect(bmiMetric != nil)
        #expect(bmiMetric?.value == 23.4)
        #expect(bmiMetric?.isHistorical == true)
    }

    // MARK: - No Data

    @Test("Empty state when all services return no data")
    func emptyState() async {
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService()
        )

        await vm.loadData()

        #expect(vm.sortedMetrics.isEmpty)
        #expect(vm.conditionScore == nil)
    }
}
