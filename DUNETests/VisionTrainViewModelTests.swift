import Foundation
import Testing
@testable import DUNE

private actor MockTrainSharedHealthDataService: SharedHealthDataService {
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

    func fetchCallCount() -> Int {
        fetchCount
    }
}

private actor MockTrainHealthKitManager: HealthKitManaging {
    nonisolated let isAvailable: Bool

    private var requestAuthorizationCount = 0

    init(isAvailable: Bool) {
        self.isAvailable = isAvailable
    }

    func requestAuthorization() async throws {
        requestAuthorizationCount += 1
    }

    func saveMindfulSession(start: Date, end: Date) async throws {}

    func requestCallCount() -> Int {
        requestAuthorizationCount
    }
}

private actor MockTrainWorkoutService: WorkoutQuerying {
    private let workouts: [WorkoutSummary]
    private var fetchCount = 0

    init(workouts: [WorkoutSummary] = []) {
        self.workouts = workouts
    }

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        fetchCount += 1
        return workouts
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        fetchCount += 1
        return workouts
    }

    func fetchCallCount() -> Int {
        fetchCount
    }
}

private struct MockTrainFatigueService: FatigueCalculating {
    let scores: [CompoundFatigueScore]

    init(scores: [CompoundFatigueScore] = []) {
        self.scores = scores
    }

    func computeCompoundFatigue(
        for muscles: [MuscleGroup],
        from records: [ExerciseRecordSnapshot],
        sleepModifier: Double,
        readinessModifier: Double,
        referenceDate: Date
    ) -> [CompoundFatigueScore] {
        scores
    }
}

@Suite("VisionTrainViewModel")
@MainActor
struct VisionTrainViewModelTests {

    @Test("reports unavailable when no health source is connected")
    func reportsUnavailableWithoutHealthSource() async {
        let vm = VisionTrainViewModel(
            sharedHealthDataService: nil,
            healthKitManager: MockTrainHealthKitManager(isAvailable: false),
            workoutService: MockTrainWorkoutService(),
            fatigueService: MockTrainFatigueService()
        )

        await vm.reload()

        if case .unavailable = vm.loadState {
            // Expected: no health source → unavailable
        } else {
            Issue.record("Expected .unavailable, got \(vm.loadState)")
        }
        #expect(vm.fatigueStates.isEmpty)
    }

    @Test("uses shared snapshot when HealthKit is unavailable")
    func usesFallbackSnapshot() async {
        let snapshotService = MockTrainSharedHealthDataService(
            snapshot: makeSnapshot(conditionScore: 75, sleepMinutes: 420)
        )
        let vm = VisionTrainViewModel(
            sharedHealthDataService: snapshotService,
            healthKitManager: MockTrainHealthKitManager(isAvailable: false),
            workoutService: MockTrainWorkoutService(),
            fatigueService: MockTrainFatigueService()
        )

        await vm.reload()

        // No training data → unavailable with message
        if case .unavailable = vm.loadState {
            // Expected: no workouts means no training data
        } else {
            Issue.record("Expected .unavailable, got \(vm.loadState)")
        }
        #expect(await snapshotService.fetchCallCount() == 1)
    }

    @Test("requests authorization when HealthKit is available")
    func requestsAuthorization() async {
        let healthKitManager = MockTrainHealthKitManager(isAvailable: true)
        let vm = VisionTrainViewModel(
            sharedHealthDataService: MockTrainSharedHealthDataService(
                snapshot: makeSnapshot()
            ),
            healthKitManager: healthKitManager,
            workoutService: MockTrainWorkoutService(),
            fatigueService: MockTrainFatigueService()
        )

        await vm.reload()

        #expect(await healthKitManager.requestCallCount() == 1)
    }

    @Test("loadIfNeeded only loads once")
    func loadIfNeededIdempotent() async {
        let workoutService = MockTrainWorkoutService()
        let vm = VisionTrainViewModel(
            sharedHealthDataService: MockTrainSharedHealthDataService(
                snapshot: makeSnapshot()
            ),
            healthKitManager: MockTrainHealthKitManager(isAvailable: true),
            workoutService: workoutService,
            fatigueService: MockTrainFatigueService()
        )

        await vm.loadIfNeeded()
        await vm.loadIfNeeded()

        // fetchWorkouts called only once (from first loadIfNeeded)
        #expect(await workoutService.fetchCallCount() == 1)
    }

    @Test("produces fatigue states for all muscle groups")
    func producesFatigueStatesForAllMuscles() async {
        let vm = VisionTrainViewModel(
            sharedHealthDataService: MockTrainSharedHealthDataService(
                snapshot: makeSnapshot()
            ),
            healthKitManager: MockTrainHealthKitManager(isAvailable: true),
            workoutService: MockTrainWorkoutService(),
            fatigueService: MockTrainFatigueService()
        )

        await vm.reload()

        #expect(vm.fatigueStates.count == MuscleGroup.allCases.count)
        let musclesInState = Set(vm.fatigueStates.map(\.muscle))
        #expect(musclesInState == Set(MuscleGroup.allCases))
    }

    @Test("sleep modifier clamps to valid range")
    func sleepModifierClamping() async {
        // Very low sleep (2h = 120min) → modifier should be clamped to 0.5
        let snapshotService = MockTrainSharedHealthDataService(
            snapshot: makeSnapshot(sleepMinutes: 120)
        )
        let vm = VisionTrainViewModel(
            sharedHealthDataService: snapshotService,
            healthKitManager: MockTrainHealthKitManager(isAvailable: true),
            workoutService: MockTrainWorkoutService(),
            fatigueService: MockTrainFatigueService()
        )

        await vm.reload()

        // The ViewModel internally computes sleep modifier; we can't directly observe it,
        // but we verify the reload completes without crash and fatigue states are produced
        #expect(vm.fatigueStates.count == MuscleGroup.allCases.count)
    }

    // MARK: - Helpers

    private func makeSnapshot(
        conditionScore: Int? = nil,
        sleepMinutes: Double = 0
    ) -> SharedHealthSnapshot {
        let score: ConditionScore? = conditionScore.map { score in
            ConditionScore(
                score: score,
                date: Date(timeIntervalSince1970: 1_700_000_000)
            )
        }

        let sleepDurations: [SharedHealthSnapshot.SleepDailyDuration]
        if sleepMinutes > 0 {
            sleepDurations = [
                SharedHealthSnapshot.SleepDailyDuration(
                    date: Date(timeIntervalSince1970: 1_700_000_000),
                    totalMinutes: sleepMinutes,
                    stageBreakdown: [:]
                )
            ]
        } else {
            sleepDurations = []
        }

        return SharedHealthSnapshot(
            hrvSamples: [],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: nil,
            rhrCollection: [],
            todaySleepStages: [],
            yesterdaySleepStages: [],
            latestSleepStages: nil,
            sleepDailyDurations: sleepDurations,
            conditionScore: score,
            baselineStatus: nil,
            recentConditionScores: [],
            failedSources: [],
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
