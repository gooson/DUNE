import Testing
import Foundation
@testable import DUNE

// MARK: - Mock Services for ActivityViewModel

private struct MockWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []
    var shouldThrow = false

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        if shouldThrow { throw TestError.mockFailure }
        return workouts
    }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        if shouldThrow { throw TestError.mockFailure }
        return workouts
    }
}

private struct MockStepsService: StepsQuerying {
    var stepsCollection: [(date: Date, sum: Double)] = []
    var shouldThrow = false

    func fetchSteps(for date: Date) async throws -> Double? { nil }
    func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchStepsCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, sum: Double)] {
        if shouldThrow { throw TestError.mockFailure }
        return stepsCollection
    }
}

private actor MockHRVService: HRVQuerying {
    private(set) var latestRHRRequestDays: [Int] = []
    let latestRHRResult: (value: Double, date: Date)?

    init(latestRHRResult: (value: Double, date: Date)? = nil) {
        self.latestRHRResult = latestRHRResult
    }

    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { [] }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        latestRHRRequestDays.append(days)
        return latestRHRResult
    }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { [] }
}

private struct MockSleepService: SleepQuerying {
    func fetchSleepStages(for date: Date) async throws -> [SleepStage] { [] }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { nil }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] { [] }
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? { nil }
}

private actor MockSharedHealthDataService: SharedHealthDataService {
    private let snapshot: SharedHealthSnapshot

    init(snapshot: SharedHealthSnapshot) {
        self.snapshot = snapshot
    }

    func fetchSnapshot() async -> SharedHealthSnapshot { snapshot }
    func invalidateCache() async {}
}

private actor SuspendingActivitySharedHealthDataService: SharedHealthDataService {
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

private actor StartupTrackingWorkoutService: WorkoutQuerying {
    private(set) var fetchCallCount = 0

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        fetchCallCount += 1
        return []
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        fetchCallCount += 1
        return []
    }
}

private actor SequencedActivityWorkoutService: WorkoutQuerying {
    private let firstRecentWorkouts: [WorkoutSummary]
    private let secondRecentWorkouts: [WorkoutSummary]
    private var recentFetchCount = 0
    private var didStartFirstFetch = false
    private var fetchStartedContinuation: CheckedContinuation<Void, Never>?
    private var fetchReleaseContinuation: CheckedContinuation<Void, Never>?

    init(firstRecentWorkouts: [WorkoutSummary], secondRecentWorkouts: [WorkoutSummary]) {
        self.firstRecentWorkouts = firstRecentWorkouts
        self.secondRecentWorkouts = secondRecentWorkouts
    }

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        recentFetchCount += 1
        if recentFetchCount == 1 {
            didStartFirstFetch = true
            fetchStartedContinuation?.resume()
            fetchStartedContinuation = nil
            await withCheckedContinuation { continuation in
                fetchReleaseContinuation = continuation
            }
            return firstRecentWorkouts
        }
        return secondRecentWorkouts
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] { [] }

    func waitUntilFirstFetchStarts() async {
        if didStartFirstFetch { return }
        await withCheckedContinuation { continuation in
            fetchStartedContinuation = continuation
        }
    }

    func resumeFirstFetch() {
        fetchReleaseContinuation?.resume()
        fetchReleaseContinuation = nil
    }
}

private func makeEmptyActivitySharedSnapshot(fetchedAt: Date = Date()) -> SharedHealthSnapshot {
    SharedHealthSnapshot(
        hrvSamples: [],
        todayRHR: nil,
        yesterdayRHR: nil,
        latestRHR: SharedHealthSnapshot.RHRSample(value: 56, date: fetchedAt),
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

private final class MockRecommendationService: WorkoutRecommending, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var lastConstraints: WorkoutRecommendationConstraints = .none

    func recommend(
        from records: [ExerciseRecordSnapshot],
        library: ExerciseLibraryQuerying,
        constraints: WorkoutRecommendationConstraints
    ) -> WorkoutSuggestion? {
        callCount += 1
        lastConstraints = constraints
        return nil
    }

    func computeFatigueStates(
        from records: [ExerciseRecordSnapshot],
        sleepModifier: Double,
        readinessModifier: Double
    ) -> [MuscleFatigueState] {
        []
    }
}

private enum TestError: Error {
    case mockFailure
}

// MARK: - Tests

@Suite("ActivityViewModel")
@MainActor
struct ActivityViewModelTests {

    private let calendar = Calendar.current

    private func makeStrengthRecord() -> ExerciseRecord {
        let record = ExerciseRecord(
            date: Date(),
            exerciseType: "Bench Press",
            duration: 900,
            exerciseDefinitionID: "bench-press",
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps],
            equipment: .barbell
        )
        let set = WorkoutSet(
            setNumber: 1,
            setType: .working,
            weight: 80,
            reps: 8,
            isCompleted: true
        )
        set.exerciseRecord = record
        record.sets = [set]
        return record
    }

    private func makeIsolatedPRStore() -> PersonalRecordStore {
        let suiteName = "ActivityViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return PersonalRecordStore(defaults: defaults)
    }

    private func makeIsolatedRecommendationStore() -> WorkoutRecommendationSettingsStore {
        let suiteName = "ActivityViewModelTests.Recommendation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return WorkoutRecommendationSettingsStore(defaults: defaults)
    }

    private func makeViewModel(
        workoutService: WorkoutQuerying = MockWorkoutService(),
        stepsService: StepsQuerying = MockStepsService(),
        hrvService: HRVQuerying = MockHRVService(),
        sleepService: SleepQuerying = MockSleepService(),
        recommendationService: WorkoutRecommending? = nil,
        sharedHealthDataService: SharedHealthDataService? = nil,
        personalRecordStore: PersonalRecordStore = .shared,
        recommendationSettingsStore: WorkoutRecommendationSettingsStore = .shared
    ) -> ActivityViewModel {
        ActivityViewModel(
            workoutService: workoutService,
            stepsService: stepsService,
            hrvService: hrvService,
            sleepService: sleepService,
            recommendationService: recommendationService,
            sharedHealthDataService: sharedHealthDataService ?? MockSharedHealthDataService(
                snapshot: makeEmptyActivitySharedSnapshot()
            ),
            personalRecordStore: personalRecordStore,
            recommendationSettingsStore: recommendationSettingsStore
        )
    }

    @Test("record change fingerprint changes when completed set data changes")
    func recordChangeFingerprintTracksCompletedSetEdits() {
        let record = makeStrengthRecord()
        let original = ActivityRecordChangeFingerprint.make(from: [record])

        record.sets?.first?.reps = 10

        let updated = ActivityRecordChangeFingerprint.make(from: [record])

        #expect(original != updated)
    }

    // MARK: - Parallel Loading

    @Test("loads exercise, steps, and workouts in parallel")
    func parallelLoading() async {
        let today = calendar.startOfDay(for: Date())

        let workouts = MockWorkoutService(workouts: [
            WorkoutSummary(id: "1", type: "Running", duration: 1800, calories: 200, distance: 5000, date: today),
        ])
        let steps = MockStepsService(stepsCollection: [
            (date: today, sum: 8500),
        ])

        let vm = makeViewModel(workoutService: workouts, stepsService: steps)
        await vm.loadActivityData()

        #expect(vm.todayExercise != nil)
        #expect(vm.todayExercise!.value == 30.0) // 1800/60
        #expect(vm.todaySteps != nil)
        #expect(vm.todaySteps!.value == 8500.0)
        #expect(vm.recentWorkouts.count == 1)
        #expect(vm.isLoading == false)
    }

    @Test("Workout fetch starts before shared snapshot resolves")
    func workoutFetchStartsBeforeSharedSnapshotCompletes() async {
        let sharedService = SuspendingActivitySharedHealthDataService(
            snapshot: makeEmptyActivitySharedSnapshot()
        )
        let workoutService = StartupTrackingWorkoutService()
        let recordStore = makeIsolatedPRStore()
        _ = recordStore.updateIfNewRecords(
            WorkoutSummary(
                id: "seed",
                type: "Running",
                duration: 1_800,
                calories: 220,
                distance: 5_000,
                date: Date()
            )
        )
        let vm = makeViewModel(
            workoutService: workoutService,
            stepsService: MockStepsService(),
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            sharedHealthDataService: sharedService,
            personalRecordStore: recordStore,
            recommendationSettingsStore: makeIsolatedRecommendationStore()
        )

        let loadTask = Task {
            await vm.loadActivityData()
        }

        await sharedService.waitUntilFetchStarts()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(await workoutService.fetchCallCount > 0)

        await sharedService.resumeFetch()
        await loadTask.value
    }

    @Test("newer activity refresh ignores an older delayed workout response")
    func newerActivityRefreshWinsOverOlderResponse() async {
        let workout = WorkoutSummary(
            id: "run-1",
            type: "Running",
            activityType: .running,
            duration: 1_800,
            calories: 220,
            distance: 5_000,
            date: Date()
        )
        let service = SequencedActivityWorkoutService(
            firstRecentWorkouts: [workout],
            secondRecentWorkouts: []
        )
        let vm = ActivityViewModel(
            workoutService: service,
            stepsService: MockStepsService(),
            hrvService: MockHRVService(),
            sleepService: MockSleepService(),
            sharedHealthDataService: MockSharedHealthDataService(snapshot: makeEmptyActivitySharedSnapshot()),
            personalRecordStore: makeIsolatedPRStore(),
            recommendationSettingsStore: makeIsolatedRecommendationStore()
        )

        let firstTask = Task {
            await vm.loadActivityData()
        }

        await service.waitUntilFirstFetchStarts()
        await vm.loadActivityData()

        #expect(vm.recentWorkouts.isEmpty)

        await service.resumeFirstFetch()
        await firstTask.value

        #expect(vm.recentWorkouts.isEmpty)
        #expect(vm.isLoading == false)
    }

    // MARK: - Weekly Data Gap Fill

    @Test("weekly data fills gaps with zero")
    func weeklyGapFill() async {
        let today = calendar.startOfDay(for: Date())
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let steps = MockStepsService(stepsCollection: [
            (date: twoDaysAgo, sum: 10000),
            (date: today, sum: 5000),
        ])

        let vm = makeViewModel(workoutService: MockWorkoutService(), stepsService: steps)
        await vm.loadActivityData()

        // Should have 7 data points (filling gaps with 0)
        #expect(vm.weeklySteps.count == 7)

        // At least one zero-filled day
        let zeroDays = vm.weeklySteps.filter { $0.value == 0 }
        #expect(zeroDays.count >= 4) // 7 total - at most 3 with data
    }

    @Test("weekly exercise fills gaps with zero")
    func weeklyExerciseGapFill() async {
        let today = calendar.startOfDay(for: Date())

        let workouts = MockWorkoutService(workouts: [
            WorkoutSummary(id: "1", type: "Running", duration: 3600, calories: nil, distance: nil, date: today),
        ])

        let vm = makeViewModel(workoutService: workouts, stepsService: MockStepsService())
        await vm.loadActivityData()

        #expect(vm.weeklyExerciseMinutes.count == 7)
        let nonZero = vm.weeklyExerciseMinutes.filter { $0.value > 0 }
        #expect(nonZero.count == 1)
        #expect(nonZero.first!.value == 60.0)
    }

    // MARK: - Fallback / Error Handling

    @Test("gracefully handles workout service failure")
    func workoutFailure() async {
        let workouts = MockWorkoutService(shouldThrow: true)
        let steps = MockStepsService(stepsCollection: [
            (date: calendar.startOfDay(for: Date()), sum: 5000),
        ])

        let vm = makeViewModel(workoutService: workouts, stepsService: steps)
        await vm.loadActivityData()

        // Steps should still load even if workouts fail
        #expect(vm.todaySteps != nil)
        #expect(vm.todaySteps!.value == 5000.0)
        // Exercise falls back to empty
        #expect(vm.weeklyExerciseMinutes.isEmpty)
        #expect(vm.recentWorkouts.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test("gracefully handles steps service failure")
    func stepsFailure() async {
        let today = calendar.startOfDay(for: Date())
        let workouts = MockWorkoutService(workouts: [
            WorkoutSummary(id: "1", type: "Yoga", duration: 2700, calories: nil, distance: nil, date: today),
        ])
        let steps = MockStepsService(shouldThrow: true)

        let vm = makeViewModel(workoutService: workouts, stepsService: steps)
        await vm.loadActivityData()

        // Exercise should still load
        #expect(vm.todayExercise != nil)
        // Steps falls back to empty
        #expect(vm.weeklySteps.isEmpty)
        #expect(vm.todaySteps == nil)
    }

    // MARK: - Empty State

    @Test("empty state when no data")
    func emptyState() async {
        let vm = makeViewModel(
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService()
        )
        await vm.loadActivityData()

        #expect(vm.todayExercise?.value == 0)
        #expect(vm.todaySteps?.value == 0)
        #expect(vm.recentWorkouts.isEmpty)
        #expect(vm.weeklyExerciseMinutes.count == 7) // Gap-filled with zeros
    }

    // MARK: - Multiple Workouts Same Day

    @Test("multiple workouts on same day sum correctly")
    func multipleWorkoutsSameDay() async {
        let today = calendar.startOfDay(for: Date())
        let workouts = MockWorkoutService(workouts: [
            WorkoutSummary(id: "1", type: "Running", duration: 1800, calories: nil, distance: nil, date: today),
            WorkoutSummary(id: "2", type: "Strength", duration: 2400, calories: nil, distance: nil, date: today),
            WorkoutSummary(id: "3", type: "Yoga", duration: 600, calories: nil, distance: nil, date: today),
        ])

        let vm = makeViewModel(workoutService: workouts, stepsService: MockStepsService())
        await vm.loadActivityData()

        #expect(vm.todayExercise!.value == 80.0) // (1800+2400+600)/60
        #expect(vm.recentWorkouts.count == 3)
    }

    // MARK: - Data Ordering

    @Test("weekly data is sorted chronologically")
    func dataSortOrder() async {
        let today = calendar.startOfDay(for: Date())
        let steps = MockStepsService(stepsCollection: [
            (date: today, sum: 5000),
            (date: calendar.date(byAdding: .day, value: -3, to: today)!, sum: 8000),
        ])

        let vm = makeViewModel(workoutService: MockWorkoutService(), stepsService: steps)
        await vm.loadActivityData()

        // Verify ascending date order
        for i in 1..<vm.weeklySteps.count {
            #expect(vm.weeklySteps[i].date >= vm.weeklySteps[i - 1].date)
        }
    }

    @Test("training load keeps 30-day RHR fallback when shared snapshot has no effective RHR")
    func trainingLoadUses30DayFallbackWithSharedSnapshot() async {
        let now = Date()
        let hrvService = MockHRVService(latestRHRResult: (value: 56, date: now))
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
            conditionScore: nil,
            baselineStatus: nil,
            recentConditionScores: [],
            failedSources: [],
            fetchedAt: now
        )

        let vm = makeViewModel(
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            hrvService: hrvService,
            sleepService: MockSleepService(),
            sharedHealthDataService: MockSharedHealthDataService(snapshot: snapshot)
        )

        await vm.loadActivityData()

        let requestedDays = await hrvService.latestRHRRequestDays
        #expect(requestedDays.contains(30))
    }

    // MARK: - Personal Records (Unified)

    @Test("manual cardio fallback appears in unified personal records")
    func manualCardioFallbackPR() {
        let store = makeIsolatedPRStore()
        let vm = makeViewModel(
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            personalRecordStore: store
        )

        let record = ExerciseRecord(
            date: Date(),
            exerciseType: "Running",
            duration: 1_800,
            calories: 320,
            distance: 5_000
        )

        vm.updateSuggestion(records: [record])

        #expect(vm.personalRecords.contains { $0.kind == .longestDistance })
        #expect(vm.personalRecords.contains { $0.kind == .fastestPace })
        #expect(vm.personalRecords.contains { $0.kind == .highestCalories })
    }

    @Test("HealthKit cardio records take precedence over manual fallback")
    func healthKitCardioPrecedence() {
        let store = makeIsolatedPRStore()
        let vm = makeViewModel(
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            personalRecordStore: store
        )

        let hkWorkout = WorkoutSummary(
            id: "hk-running-1",
            type: WorkoutActivityType.running.typeName,
            activityType: .running,
            duration: 1_500,
            calories: 400,
            distance: 10_000,
            date: Date()
        )
        _ = store.updateIfNewRecords(hkWorkout)

        let manualRecord = ExerciseRecord(
            date: Date(),
            exerciseType: "Running",
            duration: 2_100,
            calories: 500,
            distance: 12_000
        )
        vm.updateSuggestion(records: [manualRecord])

        let distanceRecord = vm.personalRecords.first { $0.kind == .longestDistance }
        #expect(distanceRecord != nil)
        #expect(distanceRecord?.source == .healthKit)
        #expect(distanceRecord?.value == 10_000)
    }

    @Test("refreshSuggestionFromRecords updates derived stats when debounce is disabled")
    func refreshSuggestionFromRecordsImmediate() async {
        let store = makeIsolatedPRStore()
        let vm = makeViewModel(
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            personalRecordStore: store
        )

        let record = ExerciseRecord(
            date: Date(),
            exerciseType: "Running",
            duration: 1_800,
            calories: 320,
            distance: 5_000
        )

        await vm.refreshSuggestionFromRecords([record], debounceNanoseconds: 0)

        #expect(vm.personalRecords.contains { $0.kind == .longestDistance })
        #expect(vm.personalRecords.contains { $0.kind == .fastestPace })
    }

    @Test("refreshSuggestionFromRecords does not mutate state when cancelled during debounce")
    func refreshSuggestionFromRecordsCancellation() async {
        let store = makeIsolatedPRStore()
        let vm = makeViewModel(
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            personalRecordStore: store
        )

        let record = ExerciseRecord(
            date: Date(),
            exerciseType: "Running",
            duration: 1_800,
            calories: 320,
            distance: 5_000
        )

        let task = Task {
            await vm.refreshSuggestionFromRecords([record], debounceNanoseconds: 1_000_000_000)
        }
        task.cancel()
        await task.value

        #expect(vm.personalRecords.isEmpty)
    }

    @Test("recommendation exclusion persists and updates constraints")
    func recommendationExclusionPersists() {
        let store = makeIsolatedRecommendationStore()
        let recommendationService = MockRecommendationService()
        let vm = makeViewModel(
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            recommendationService: recommendationService,
            recommendationSettingsStore: store
        )

        vm.updateSuggestion(records: [])
        let baselineCallCount = recommendationService.callCount

        vm.setExerciseExcludedFromRecommendation(true, exerciseID: "pushup")

        #expect(vm.isExerciseExcludedFromRecommendation("pushup") == true)
        #expect(recommendationService.callCount == baselineCallCount + 1)
        #expect(recommendationService.lastConstraints.excludedExerciseIDs.contains("pushup"))
    }

    @Test("equipment and context updates are reflected in recommendation constraints")
    func equipmentAndContextUpdatesConstraints() {
        let store = makeIsolatedRecommendationStore()
        let recommendationService = MockRecommendationService()
        let vm = makeViewModel(
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService(),
            recommendationService: recommendationService,
            recommendationSettingsStore: store
        )

        vm.updateSuggestion(records: [])
        vm.setRecommendationContext(.home)
        vm.setEquipmentAvailability(.dumbbell, isAvailable: false)

        #expect(vm.recommendationContext == .home)
        #expect(recommendationService.lastConstraints.allowedEquipment?.contains(.dumbbell) == false)
    }

    @Test("weekly report includes HealthKit-only workouts")
    func weeklyReportIncludesHealthKitWorkouts() async {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let hkWorkout = WorkoutSummary(
            id: "HK-THIRD-PARTY",
            type: "Running",
            activityType: .running,
            duration: 1800,
            calories: 300,
            distance: 5000,
            date: yesterday,
            isFromThisApp: false
        )
        let workoutService = MockWorkoutService(workouts: [hkWorkout])

        let store = makeIsolatedPRStore()
        let vm = makeViewModel(
            workoutService: workoutService,
            stepsService: MockStepsService(),
            personalRecordStore: store
        )

        // Load HealthKit data (populates recentWorkouts)
        await vm.loadActivityData()
        // No SwiftData records — exerciseRecordSnapshots is empty
        vm.updateSuggestion(records: [])
        vm.generateWeeklyReport()

        // Allow the async Task inside generateWeeklyReport to complete
        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(vm.weeklyReport != nil, "Weekly report should include HealthKit-only workouts")
        if let report = vm.weeklyReport {
            #expect(report.stats.totalSessions == 1)
            #expect(report.stats.activeDays == 1)
        }
    }

    @Test("weekly report merges SwiftData and HealthKit workouts without duplication")
    func weeklyReportMergesWithoutDuplication() async {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // SwiftData record (from app)
        let record = ExerciseRecord(
            date: yesterday,
            exerciseType: "Bench Press",
            duration: 2400,
            calories: 200,
            distance: nil
        )
        record.primaryMusclesRaw = [MuscleGroup.chest.rawValue]
        record.healthKitWorkoutID = "HK-APP-1"

        // HealthKit workout linked to the above record
        let linkedHKWorkout = WorkoutSummary(
            id: "HK-APP-1",
            type: "Bench Press",
            activityType: .traditionalStrengthTraining,
            duration: 2400,
            calories: 200,
            distance: nil,
            date: yesterday,
            isFromThisApp: true
        )

        // HealthKit third-party workout (not in SwiftData)
        let thirdPartyWorkout = WorkoutSummary(
            id: "HK-THIRD-PARTY",
            type: "Running",
            activityType: .running,
            duration: 1800,
            calories: 300,
            distance: 5000,
            date: yesterday,
            isFromThisApp: false
        )

        let workoutService = MockWorkoutService(workouts: [linkedHKWorkout, thirdPartyWorkout])
        let store = makeIsolatedPRStore()
        let vm = makeViewModel(
            workoutService: workoutService,
            stepsService: MockStepsService(),
            personalRecordStore: store
        )

        await vm.loadActivityData()
        vm.updateSuggestion(records: [record])
        vm.generateWeeklyReport()

        try? await Task.sleep(nanoseconds: 200_000_000)

        #expect(vm.weeklyReport != nil)
        if let report = vm.weeklyReport {
            // 1 SwiftData record + 1 third-party HK = 2 (linked HK excluded)
            #expect(report.stats.totalSessions == 2)
        }
    }
}
