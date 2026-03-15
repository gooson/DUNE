import Foundation
import Testing
@testable import DUNE

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
    func fetchBodyFat(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLeanBodyMass(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
}

private actor MockWeatherProvider: WeatherProviding {
    enum TestError: Error {
        case fetchFailed
    }

    private var snapshot: WeatherSnapshot?
    private var shouldFailFetch: Bool
    private var permissionDetermined: Bool
    private var determinationDelayNanoseconds: UInt64?
    private(set) var permissionRequestCount = 0
    private(set) var fetchCount = 0

    init(
        snapshot: WeatherSnapshot? = nil,
        shouldFailFetch: Bool = false,
        permissionDetermined: Bool = true,
        determinationDelayNanoseconds: UInt64? = nil
    ) {
        self.snapshot = snapshot
        self.shouldFailFetch = shouldFailFetch
        self.permissionDetermined = permissionDetermined
        self.determinationDelayNanoseconds = determinationDelayNanoseconds
    }

    func fetchCurrentWeather() async throws -> WeatherSnapshot {
        fetchCount += 1
        if shouldFailFetch || snapshot == nil {
            throw TestError.fetchFailed
        }
        return snapshot!
    }

    func requestLocationPermission() async {
        permissionRequestCount += 1

        guard !permissionDetermined else { return }

        if let delay = determinationDelayNanoseconds {
            Task {
                try? await Task.sleep(nanoseconds: delay)
                permissionDetermined = true
            }
        } else {
            permissionDetermined = true
        }
    }

    var isLocationPermissionDetermined: Bool {
        get async { permissionDetermined }
    }

    func callCounts() -> (permissionRequests: Int, fetches: Int) {
        (permissionRequestCount, fetchCount)
    }
}

private actor SuspendingDashboardSharedHealthDataService: SharedHealthDataService {
    private let snapshot: SharedHealthSnapshot
    private var didStartFetch = false
    private var fetchStartedContinuation: CheckedContinuation<Void, Never>?
    private var fetchReleaseContinuation: CheckedContinuation<Void, Never>?

    init(snapshot: SharedHealthSnapshot) {
        self.snapshot = snapshot
    }

    func fetchSnapshot() async -> SharedHealthSnapshot {
        didStartFetch = true
        fetchStartedContinuation?.resume()
        fetchStartedContinuation = nil

        await withCheckedContinuation { continuation in
            fetchReleaseContinuation = continuation
        }
        return snapshot
    }

    func invalidateCache() async {}

    func waitUntilFetchStarts() async {
        if didStartFetch {
            return
        }
        await withCheckedContinuation { continuation in
            fetchStartedContinuation = continuation
        }
    }

    func resumeFetch() {
        fetchReleaseContinuation?.resume()
        fetchReleaseContinuation = nil
    }
}

private actor CountingDashboardSharedHealthDataService: SharedHealthDataService {
    private let snapshot: SharedHealthSnapshot
    private var fetchCount = 0

    init(snapshot: SharedHealthSnapshot) {
        self.snapshot = snapshot
    }

    func fetchSnapshot() async -> SharedHealthSnapshot {
        fetchCount += 1
        return snapshot
    }

    func invalidateCache() async {}

    func currentFetchCount() -> Int {
        fetchCount
    }
}

private actor SequencedDashboardSharedHealthDataService: SharedHealthDataService {
    private let snapshots: [SharedHealthSnapshot]
    private var nextFetchIndex = 0
    private var startedFetches: Set<Int> = []
    private var startContinuations: [Int: CheckedContinuation<Void, Never>] = [:]
    private var releaseContinuations: [Int: CheckedContinuation<Void, Never>] = [:]

    init(snapshots: [SharedHealthSnapshot]) {
        self.snapshots = snapshots
    }

    func fetchSnapshot() async -> SharedHealthSnapshot {
        let index = nextFetchIndex
        nextFetchIndex += 1
        startedFetches.insert(index)
        startContinuations[index]?.resume()
        startContinuations[index] = nil

        await withCheckedContinuation { continuation in
            releaseContinuations[index] = continuation
        }

        return snapshots[index]
    }

    func invalidateCache() async {}

    func waitUntilFetchStarts(call index: Int) async {
        if startedFetches.contains(index) {
            return
        }

        await withCheckedContinuation { continuation in
            startContinuations[index] = continuation
        }
    }

    func resumeFetch(call index: Int) {
        releaseContinuations[index]?.resume()
        releaseContinuations[index] = nil
    }
}

private func makeEmptySharedSnapshot(fetchedAt: Date = Date()) -> SharedHealthSnapshot {
    SharedHealthSnapshot(
        hrvSamples: [],
        todayRHR: nil,
        yesterdayRHR: nil,
        latestRHR: nil,
        rhrCollection: [],
        todaySleepStages: [],
        yesterdaySleepStages: [],
        latestSleepStages: nil,
        sleepDailyDurations: [],
        conditionScore: nil,
        baselineStatus: nil,
        recentConditionScores: [],
        failedSources: [],
        fetchedAt: fetchedAt
    )
}

private func makeDashboardSharedSnapshot(hrvValue: Double) -> SharedHealthSnapshot {
    SharedHealthSnapshot(
        hrvSamples: [HRVSample(value: hrvValue, date: Date())],
        todayRHR: 55,
        yesterdayRHR: 57,
        latestRHR: nil,
        rhrCollection: [],
        todaySleepStages: [],
        yesterdaySleepStages: [],
        latestSleepStages: nil,
        sleepDailyDurations: [],
        conditionScore: nil,
        baselineStatus: nil,
        recentConditionScores: [],
        failedSources: [],
        fetchedAt: Date()
    )
}

private func makeTestWeatherSnapshot(
    condition: WeatherConditionType = .rain
) -> WeatherSnapshot {
    WeatherSnapshot(
        temperature: 21,
        feelsLike: 22,
        condition: condition,
        humidity: 0.6,
        uvIndex: 4,
        windSpeed: 12,
        isDaytime: true,
        fetchedAt: Date(),
        hourlyForecast: [],
        dailyForecast: [],
        locationName: "Seoul",
        airQuality: nil
    )
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

    @Test("Deferred HealthKit gate skips protected queries until launch authorization completes")
    func deferredHealthKitGateSkipsProtectedQueriesUntilEnabled() async {
        let hrv = MockHRVService(
            samples: [HRVSample(value: 48.0, date: Date())],
            todayRHR: 56.0,
            yesterdayRHR: 58.0,
            latestRHR: nil
        )
        let sharedHealthDataService = CountingDashboardSharedHealthDataService(
            snapshot: SharedHealthSnapshot(
                hrvSamples: [HRVSample(value: 48.0, date: Date())],
                todayRHR: 56.0,
                yesterdayRHR: 58.0,
                latestRHR: nil,
                rhrCollection: [],
                todaySleepStages: [],
                yesterdaySleepStages: [],
                latestSleepStages: nil,
                sleepDailyDurations: [],
                conditionScore: nil,
                baselineStatus: nil,
                recentConditionScores: [],
                failedSources: [],
                fetchedAt: Date()
            )
        )
        let vm = DashboardViewModel(
            hrvService: hrv,
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            sharedHealthDataService: sharedHealthDataService,
            weatherProvider: MockWeatherProvider(snapshot: makeTestWeatherSnapshot()),
            coachingMessageEnhancer: nil
        )

        await vm.loadData(canLoadHealthKitData: false)

        #expect(vm.sortedMetrics.isEmpty)
        #expect(await sharedHealthDataService.currentFetchCount() == 0)

        await vm.loadData(canLoadHealthKitData: true)

        #expect(vm.sortedMetrics.contains { $0.category == .hrv })
        #expect(await sharedHealthDataService.currentFetchCount() == 1)
    }

    @Test("Shared snapshot source failure does not show partial error when fallback metric is available")
    func sharedSnapshotFailureWithFallbackDoesNotShowError() async {
        let now = Date()
        let sleepDate = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let sleepStages = [
            SleepStage(stage: .core, duration: 3600, startDate: sleepDate, endDate: sleepDate.addingTimeInterval(3600))
        ]
        let snapshot = SharedHealthSnapshot(
            hrvSamples: [HRVSample(value: 48.0, date: now)],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: SharedHealthSnapshot.RHRSample(value: 56.0, date: now),
            rhrCollection: [],
            todaySleepStages: [],
            yesterdaySleepStages: [],
            latestSleepStages: SharedHealthSnapshot.SleepStagesSample(stages: sleepStages, date: sleepDate),
            sleepDailyDurations: [
                SharedHealthSnapshot.SleepDailyDuration(
                    date: sleepDate,
                    totalMinutes: 360,
                    stageBreakdown: [.core: 360]
                )
            ],
            conditionScore: nil,
            baselineStatus: nil,
            recentConditionScores: [],
            failedSources: [.todaySleepStages, .todayRHR],
            fetchedAt: now
        )
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            sharedHealthDataService: CountingDashboardSharedHealthDataService(snapshot: snapshot),
            weatherProvider: MockWeatherProvider(snapshot: makeTestWeatherSnapshot()),
            coachingMessageEnhancer: nil
        )

        await vm.loadData()

        #expect(vm.sortedMetrics.contains { $0.category == .hrv })
        #expect(vm.sortedMetrics.contains { $0.category == .sleep })
        #expect(vm.errorMessage == nil)
    }

    @Test("Shared snapshot source failure shows partial error when category card cannot be built")
    func sharedSnapshotFailureWithoutFallbackShowsError() async {
        let now = Date()
        let snapshot = SharedHealthSnapshot(
            hrvSamples: [],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: nil,
            rhrCollection: [],
            todaySleepStages: [],
            yesterdaySleepStages: [],
            latestSleepStages: nil,
            sleepDailyDurations: [],
            todaySteps: 1200,
            conditionScore: nil,
            baselineStatus: nil,
            recentConditionScores: [],
            failedSources: [.hrvSamples],
            fetchedAt: now
        )
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            sharedHealthDataService: CountingDashboardSharedHealthDataService(snapshot: snapshot),
            weatherProvider: MockWeatherProvider(snapshot: makeTestWeatherSnapshot()),
            coachingMessageEnhancer: nil
        )

        await vm.loadData()

        #expect(vm.sortedMetrics.contains { $0.category == .steps })
        #expect(vm.errorMessage?.contains("Some data could not be loaded") == true)
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

    @Test("Coaching insight and message are generated even when score is unavailable")
    func coachingWithoutScore() async {
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService()
        )

        await vm.loadData()

        // focusInsight should be populated from CoachingEngine (Korean default messages)
        #expect(vm.focusInsight != nil)
        // coachingMessage derives from focusInsight?.message
        #expect(vm.coachingMessage != nil)
        #expect(!vm.coachingMessage!.isEmpty)
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

    @Test("Condition score is cleared when HRV fetch fails during refresh without shared snapshot")
    func conditionScoreIsClearedAfterHRVFailure() async {
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
        let initialConditionScore = vm.conditionScore
        let initialRecentScores = vm.recentScores

        await hrv.setShouldThrowSamples(true)
        await vm.loadData()

        #expect(initialConditionScore != nil)
        #expect(!initialRecentScores.isEmpty)
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

    @Test("Hero baseline details include baseline-relative RHR badge")
    func heroBaselineDetailsIncludeRHR() async {
        let calendar = Calendar.current
        let today = Date()
        let samples: [HRVSample] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return HRVSample(value: offset == 0 ? 60 : 50, date: date)
        }
        let rhrCollection: [(date: Date, min: Double, max: Double, average: Double)] = (0..<8).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let average = offset == 0 ? 64.0 : 58.0
            return (date: date, min: average - 1, max: average + 1, average: average)
        }

        let vm = DashboardViewModel(
            hrvService: MockHRVService(
                samples: samples,
                todayRHR: 64,
                yesterdayRHR: 58,
                latestRHR: (value: 64, date: today),
                rhrCollection: rhrCollection
            ),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService()
        )

        await vm.loadData()

        let rhrBadge = vm.heroBaselineDetails.first { $0.label == String(localized: "RHR vs 14d avg") }
        #expect(rhrBadge != nil)
        #expect(rhrBadge?.inversePolarity == true)
    }

    @Test("Location permission waits for resolution before weather fetch")
    func locationPermissionWaitsBeforeWeatherFetch() async {
        let weatherProvider = MockWeatherProvider(
            snapshot: makeTestWeatherSnapshot(condition: .rain),
            permissionDetermined: false,
            determinationDelayNanoseconds: 150_000_000
        )
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            weatherProvider: weatherProvider
        )

        await vm.requestLocationPermission()

        #expect(vm.weatherSnapshot != nil)
        #expect(vm.weatherSnapshot?.condition == .rain)
        if let snapshot = vm.weatherSnapshot {
            #expect(vm.weatherAtmosphere == WeatherAtmosphere.from(snapshot))
        } else {
            Issue.record("Expected weather snapshot to be populated after permission resolution")
        }
        let counts = await weatherProvider.callCounts()
        #expect(counts.permissionRequests == 1)
        #expect(counts.fetches == 1)
    }

    @Test("Location permission refresh works when already determined")
    func locationPermissionRefreshWhenAlreadyDetermined() async {
        let weatherProvider = MockWeatherProvider(
            snapshot: makeTestWeatherSnapshot(condition: .clear),
            permissionDetermined: true
        )
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            weatherProvider: weatherProvider
        )

        await vm.requestLocationPermission()

        #expect(vm.weatherSnapshot?.condition == .clear)
        let counts = await weatherProvider.callCounts()
        #expect(counts.permissionRequests == 1)
        #expect(counts.fetches == 1)
    }

    @Test("Weather fetch starts before shared snapshot resolves")
    func weatherStartsBeforeSharedSnapshotCompletes() async {
        let sharedService = SuspendingDashboardSharedHealthDataService(
            snapshot: makeEmptySharedSnapshot()
        )
        let weatherProvider = MockWeatherProvider(snapshot: makeTestWeatherSnapshot(condition: .clear))
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            sharedHealthDataService: sharedService,
            weatherProvider: weatherProvider
        )

        let loadTask = Task {
            await vm.loadData()
        }

        await sharedService.waitUntilFetchStarts()
        try? await Task.sleep(for: .milliseconds(20))

        let counts = await weatherProvider.callCounts()
        #expect(counts.fetches == 1)

        await sharedService.resumeFetch()
        _ = await loadTask.result
    }

    @Test("Latest dashboard load wins over older response")
    func latestDashboardLoadWinsOverOlderResponse() async {
        let sharedService = SequencedDashboardSharedHealthDataService(
            snapshots: [
                makeDashboardSharedSnapshot(hrvValue: 22),
                makeDashboardSharedSnapshot(hrvValue: 71),
            ]
        )
        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            sharedHealthDataService: sharedService,
            weatherProvider: MockWeatherProvider(snapshot: makeTestWeatherSnapshot()),
            coachingMessageEnhancer: nil
        )

        let firstLoad = Task { await vm.loadData() }
        await sharedService.waitUntilFetchStarts(call: 0)

        let secondLoad = Task { await vm.loadData() }
        await sharedService.waitUntilFetchStarts(call: 1)

        await sharedService.resumeFetch(call: 1)
        _ = await secondLoad.result

        await sharedService.resumeFetch(call: 0)
        _ = await firstLoad.result

        let hrvMetric = vm.sortedMetrics.first { $0.category == .hrv }
        #expect(hrvMetric?.value == 71)
        #expect(vm.isLoading == false)
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

    @Test("Walking step card is added when walking workout exists")
    func walkingStepCardAdded() async {
        let now = Date()
        let workout = MockWorkoutService(workouts: [
            WorkoutSummary(
                id: "w-walking",
                type: "Walking",
                activityType: .walking,
                duration: 2400,
                calories: 180,
                distance: 2_100,
                date: now,
                stepCount: 3_245
            )
        ])

        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: workout,
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            pinnedMetricsStore: makePinnedStore([])
        )

        await vm.loadData()

        let walkingCard = vm.activityCards.first { $0.id == "exercise-walking-steps" }
        #expect(walkingCard != nil)
        #expect(walkingCard?.title == String(localized: "Walking"))
        #expect(walkingCard?.unit == String(localized: "steps"))
        #expect(walkingCard?.value == "3,245")
    }

    @Test("Today activity workout card prefers stored HealthKit title")
    func todayActivityWorkoutCardPrefersStoredHealthKitTitle() async {
        let now = Date()
        let workout = MockWorkoutService(workouts: [
            WorkoutSummary(
                id: "w-strength",
                type: "Bench Press",
                activityType: .traditionalStrengthTraining,
                duration: 2_100,
                calories: 220,
                distance: nil,
                date: now
            )
        ])

        let vm = DashboardViewModel(
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            workoutService: workout,
            stepsService: MockStepsService(),
            bodyService: MockBodyService(),
            pinnedMetricsStore: makePinnedStore([])
        )

        await vm.loadData()

        let strengthCard = vm.activityCards.first { $0.id == "exercise-bench press" }
        #expect(strengthCard != nil)
        #expect(strengthCard?.title == "Bench Press")
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
