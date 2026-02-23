import Foundation
import Testing
@testable import Dailve

// MARK: - Mock Services

private struct MockHRVService: HRVQuerying {
    var samples: [HRVSample] = []
    var todayRHR: Double?
    var yesterdayRHR: Double?
    var latestRHR: (value: Double, date: Date)?
    var rhrCollection: [(date: Date, min: Double, max: Double, average: Double)] = []

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { samples }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return todayRHR }
        if calendar.isDateInYesterday(date) { return yesterdayRHR }
        return nil
    }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { latestRHR }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { rhrCollection }
}

private actor ToggleHRVService: HRVQuerying {
    enum TestError: Error {
        case forcedFailure
    }

    private let samples: [HRVSample]
    private let todayRHR: Double?
    private let yesterdayRHR: Double?
    private let latestRHR: (value: Double, date: Date)?
    private let rhrCollection: [(date: Date, min: Double, max: Double, average: Double)]
    private var shouldThrowSamples = false

    init(
        samples: [HRVSample],
        todayRHR: Double?,
        yesterdayRHR: Double?,
        latestRHR: (value: Double, date: Date)? = nil,
        rhrCollection: [(date: Date, min: Double, max: Double, average: Double)] = []
    ) {
        self.samples = samples
        self.todayRHR = todayRHR
        self.yesterdayRHR = yesterdayRHR
        self.latestRHR = latestRHR
        self.rhrCollection = rhrCollection
    }

    func setShouldThrowSamples(_ shouldThrow: Bool) {
        shouldThrowSamples = shouldThrow
    }

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] {
        if shouldThrowSamples {
            throw TestError.forcedFailure
        }
        return samples
    }

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return todayRHR }
        if calendar.isDateInYesterday(date) { return yesterdayRHR }
        return nil
    }

    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        latestRHR
    }

    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] {
        []
    }

    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] {
        rhrCollection
    }
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
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
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
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
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

    @Test("Pinned metrics honor saved category order")
    func pinnedMetricsOrder() async {
        let today = Date()
        let sleepStages = [
            SleepStage(stage: .core, duration: 3600, startDate: today, endDate: today.addingTimeInterval(3600))
        ]
        let hrv = MockHRVService(
            samples: [HRVSample(value: 50.0, date: today)],
            todayRHR: 58.0,
            yesterdayRHR: 60.0,
            latestRHR: nil
        )
        let workout = MockWorkoutService(workouts: [
            WorkoutSummary(id: "w1", type: "Running", duration: 1800, calories: 200, distance: nil, date: today)
        ])
        let steps = MockStepsService(todaySteps: 7000, yesterdaySteps: 6000, latestSteps: nil)
        let pinnedStore = makePinnedStore([.steps, .exercise, .hrv])

        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(todayStages: sleepStages, yesterdayStages: [], latestStages: nil),
            workoutService: workout,
            stepsService: steps,
            pinnedMetricsStore: pinnedStore
        )

        await vm.loadData()

        #expect(vm.pinnedMetrics.map(\.category) == [.steps, .exercise, .hrv])
        #expect(vm.conditionCards.contains(where: { $0.category == .hrv }) == false)
    }

    @Test("Coaching message is generated even when score is unavailable")
    func coachingWithoutScore() async {
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService()
        )

        await vm.loadData()

        #expect(vm.coachingMessage != nil)
        #expect(vm.coachingMessage?.contains("No score yet") == true)
    }

    @Test("HRV baseline delta is computed when enough samples exist")
    func hrvBaselineDelta() async {
        let calendar = Calendar.current
        let samples = (0..<16).compactMap { offset -> HRVSample? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return HRVSample(value: 45 + Double(offset), date: date)
        }
        let hrv = MockHRVService(
            samples: samples,
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

        let delta = vm.baselineDeltasByMetricID["hrv"]
        #expect(delta != nil)
        #expect(delta?.shortTermDelta != nil)
    }

    @Test("Condition score resets when HRV fetch fails on refresh")
    func conditionScoreClearsAfterHRVFailure() async {
        let calendar = Calendar.current
        let samples = (0..<7).compactMap { offset -> HRVSample? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return HRVSample(value: 52.0 + Double(offset), date: date)
        }
        let hrv = ToggleHRVService(
            samples: samples,
            todayRHR: 58.0,
            yesterdayRHR: 60.0
        )
        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService()
        )

        await vm.loadData()
        #expect(vm.conditionScore != nil)

        await hrv.setShouldThrowSamples(true)
        await vm.loadData()

        #expect(vm.conditionScore == nil)
        #expect(vm.recentScores.isEmpty)
    }

    @Test("Weekly goal counts only workouts in current calendar week")
    func weeklyGoalUsesCalendarWeek() async {
        let calendar = Calendar.current
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start,
              let previousWeekDate = calendar.date(byAdding: .day, value: -1, to: weekStart) else {
            Issue.record("Failed to build week boundary dates for test")
            return
        }

        let workouts = MockWorkoutService(workouts: [
            WorkoutSummary(id: "this-week", type: "Running", duration: 1800, calories: 200, distance: nil, date: weekStart),
            WorkoutSummary(id: "prev-week", type: "Running", duration: 1800, calories: 180, distance: nil, date: previousWeekDate)
        ])
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: workouts,
            stepsService: MockStepsService()
        )

        await vm.loadData()

        #expect(vm.weeklyGoalProgress.completedDays == 1)
    }

    @Test("RHR baseline excludes current comparison day")
    func rhrBaselineExcludesCurrentDay() async {
        let calendar = Calendar.current
        let today = Date()
        guard let fallbackDate = calendar.date(byAdding: .day, value: -1, to: today),
              let olderDate = calendar.date(byAdding: .day, value: -2, to: today) else {
            Issue.record("Failed to build date fixtures for RHR baseline test")
            return
        }

        let hrv = MockHRVService(
            samples: [HRVSample(value: 50.0, date: today)],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: (value: 60.0, date: fallbackDate),
            rhrCollection: [
                (date: fallbackDate, min: 60.0, max: 60.0, average: 60.0),
                (date: olderDate, min: 50.0, max: 50.0, average: 50.0)
            ]
        )
        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService()
        )

        await vm.loadData()

        #expect(vm.baselineDeltasByMetricID["rhr"]?.shortTermDelta == 10.0)
    }

    private func makePinnedStore(_ categories: [HealthMetric.Category]) -> TodayPinnedMetricsStore {
        let suiteName = "DashboardPinnedStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let store = TodayPinnedMetricsStore(defaults: defaults)
        store.save(categories)
        return store
    }
}

// MARK: - VitalCardData Conversion Tests

@Suite("DashboardViewModel VitalCardData")
@MainActor
struct DashboardViewModelVitalCardTests {

    @Test("Condition cards contain HRV and RHR")
    func conditionCardsContainHRVAndRHR() async {
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
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            pinnedMetricsStore: makePinnedStore([.weight])
        )

        await vm.loadData()

        let categories = Set(vm.conditionCards.map(\.category))
        #expect(categories.contains(.hrv))
        #expect(categories.contains(.rhr))
    }

    @Test("Activity cards contain steps and exercise")
    func activityCardsContainStepsAndExercise() async {
        let steps = MockStepsService(todaySteps: 7000, yesterdaySteps: 6000, latestSteps: nil)
        let workout = MockWorkoutService(workouts: [
            WorkoutSummary(id: "w1", type: "Running", duration: 1800, calories: 200, distance: nil, date: Date())
        ])
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: workout,
            stepsService: steps,
            bodyService: MockBodyService(),
            pinnedMetricsStore: makePinnedStore([])
        )

        await vm.loadData()

        let categories = Set(vm.activityCards.map(\.category))
        #expect(categories.contains(.steps))
        #expect(categories.contains(.exercise))
    }

    @Test("Body cards contain weight and BMI")
    func bodyCardsContainWeightAndBMI() async {
        let today = Date()
        let body = MockBodyService(
            latestWeight: (value: 72.5, date: today),
            latestBMI: (value: 23.1, date: today)
        )
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: body,
            pinnedMetricsStore: makePinnedStore([])
        )

        await vm.loadData()

        let categories = Set(vm.bodyCards.map(\.category))
        #expect(categories.contains(.weight))
        #expect(categories.contains(.bmi))
    }

    @Test("Pinned metrics excluded from section cards")
    func pinnedExcludedFromSections() async {
        let today = Date()
        let hrv = MockHRVService(
            samples: [HRVSample(value: 50.0, date: today)],
            todayRHR: 58.0,
            yesterdayRHR: 60.0,
            latestRHR: nil
        )
        let steps = MockStepsService(todaySteps: 7000, yesterdaySteps: 6000, latestSteps: nil)
        let pinnedStore = makePinnedStore([.hrv, .steps])

        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: steps,
            bodyService: MockBodyService(),
            pinnedMetricsStore: pinnedStore
        )

        await vm.loadData()

        #expect(vm.pinnedCards.contains { $0.category == .hrv })
        #expect(vm.pinnedCards.contains { $0.category == .steps })
        #expect(!vm.conditionCards.contains { $0.category == .hrv })
        #expect(!vm.activityCards.contains { $0.category == .steps })
    }

    @Test("Empty input produces empty card arrays")
    func emptyInputProducesEmptyCards() async {
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            pinnedMetricsStore: makePinnedStore([])
        )

        await vm.loadData()

        #expect(vm.pinnedCards.isEmpty)
        #expect(vm.conditionCards.isEmpty)
        #expect(vm.activityCards.isEmpty)
        #expect(vm.bodyCards.isEmpty)
    }

    @Test("VitalCardData has correct value formatting")
    func vitalCardValueFormatting() async {
        let hrv = MockHRVService(
            samples: [HRVSample(value: 45.0, date: Date())],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: nil
        )
        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            pinnedMetricsStore: makePinnedStore([.weight])
        )

        await vm.loadData()

        let hrvCard = vm.conditionCards.first { $0.category == .hrv }
        #expect(hrvCard != nil)
        #expect(hrvCard?.value == "45")
        #expect(hrvCard?.unit == "ms")
        #expect(hrvCard?.title == "HRV")
    }

    @Test("RHR card has inversePolarity set to true")
    func rhrInversePolarity() async {
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
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            pinnedMetricsStore: makePinnedStore([.weight])
        )

        await vm.loadData()

        let rhrCard = vm.conditionCards.first { $0.category == .rhr }
        #expect(rhrCard?.inversePolarity == true)

        let hrvCard = vm.conditionCards.first { $0.category == .hrv }
        #expect(hrvCard?.inversePolarity == false)
    }

    @Test("Stale card is marked when data is 3+ days old")
    func staleCardMarking() async {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let hrv = MockHRVService(
            samples: [HRVSample(value: 45.0, date: threeDaysAgo)],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: nil
        )
        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            pinnedMetricsStore: makePinnedStore([.weight])
        )

        await vm.loadData()

        let hrvCard = vm.conditionCards.first { $0.category == .hrv }
        #expect(hrvCard?.isStale == true)
    }

    @Test("Baseline detail populated when delta exists")
    func baselineDetailPopulated() async {
        let calendar = Calendar.current
        let samples = (0..<16).compactMap { offset -> HRVSample? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return HRVSample(value: 45 + Double(offset), date: date)
        }
        let hrv = MockHRVService(
            samples: samples,
            todayRHR: 58.0,
            yesterdayRHR: 60.0,
            latestRHR: nil
        )
        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            pinnedMetricsStore: makePinnedStore([.weight])
        )

        await vm.loadData()

        let hrvCard = vm.conditionCards.first { $0.category == .hrv }
        #expect(hrvCard?.baselineDetail != nil)
    }

    private func makePinnedStore(_ categories: [HealthMetric.Category]) -> TodayPinnedMetricsStore {
        let suiteName = "DashboardPinnedStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        let store = TodayPinnedMetricsStore(defaults: defaults)
        store.save(categories)
        return store
    }
}
