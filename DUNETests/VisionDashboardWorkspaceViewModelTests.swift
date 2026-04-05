import Foundation
import Testing
@testable import DUNE

private enum MockVisionWorkspaceError: Error {
    case failed
}

private actor MockVisionWorkspaceSharedHealthDataService: SharedHealthDataService {
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

private actor MockVisionWorkspaceHealthKitManager: HealthKitManaging {
    nonisolated let isAvailable: Bool

    private let requestAuthorizationError: Error?
    private var requestAuthorizationCount = 0

    init(
        isAvailable: Bool,
        requestAuthorizationError: Error? = nil
    ) {
        self.isAvailable = isAvailable
        self.requestAuthorizationError = requestAuthorizationError
    }

    func requestAuthorization() async throws {
        requestAuthorizationCount += 1
        if let requestAuthorizationError {
            throw requestAuthorizationError
        }
    }

    func saveMindfulSession(start: Date, end: Date) async throws {}

    func requestCallCount() -> Int {
        requestAuthorizationCount
    }
}

private struct MockVisionWorkspaceWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []
    var error: Error?

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        if let error { throw error }
        return workouts
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        if let error { throw error }
        return workouts
    }
}

private struct MockVisionWorkspaceBodyService: BodyCompositionQuerying {
    var weightSamples: [BodyCompositionSample] = []
    var bodyFatSamples: [BodyCompositionSample] = []
    var leanMassSamples: [BodyCompositionSample] = []
    var error: Error?

    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] {
        if let error { throw error }
        return weightSamples
    }

    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] {
        if let error { throw error }
        return bodyFatSamples
    }

    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] {
        if let error { throw error }
        return leanMassSamples
    }

    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        if let error { throw error }
        return weightSamples
    }

    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        if let error { throw error }
        guard let first = weightSamples.first else { return nil }
        return (first.value, first.date)
    }

    func fetchBMI(for date: Date) async throws -> Double? {
        if let error { throw error }
        return nil
    }

    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        if let error { throw error }
        return nil
    }

    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        if let error { throw error }
        return []
    }

    func fetchBodyFat(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        if let error { throw error }
        return []
    }

    func fetchLeanBodyMass(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        if let error { throw error }
        return []
    }

    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        if let error { throw error }
        guard let first = bodyFatSamples.first else { return nil }
        return (first.value, first.date)
    }

    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        if let error { throw error }
        guard let first = leanMassSamples.first else { return nil }
        return (first.value, first.date)
    }
}

@Suite("VisionDashboardWorkspaceViewModel")
@MainActor
struct VisionDashboardWorkspaceViewModelTests {
    @Test("loadIfNeeded builds ready workspace summary once")
    func loadIfNeededBuildsSummaryOnce() async {
        let now = Date()
        let snapshotService = MockVisionWorkspaceSharedHealthDataService(snapshot: makeSnapshot(now: now))
        let healthKitManager = MockVisionWorkspaceHealthKitManager(isAvailable: true)
        let workoutService = MockVisionWorkspaceWorkoutService(workouts: makeWorkouts(now: now))
        let bodyService = MockVisionWorkspaceBodyService(
            weightSamples: [BodyCompositionSample(value: 81.4, date: now)],
            bodyFatSamples: [BodyCompositionSample(value: 17.8, date: now)],
            leanMassSamples: [BodyCompositionSample(value: 63.2, date: now)]
        )
        let viewModel = VisionDashboardWorkspaceViewModel(
            sharedHealthDataService: snapshotService,
            healthKitManager: healthKitManager,
            workoutService: workoutService,
            bodyCompositionService: bodyService
        )

        await viewModel.loadIfNeeded()
        await viewModel.loadIfNeeded()

        #expect(viewModel.loadState == .ready)
        #expect(viewModel.summary?.condition.score == 88)
        #expect(viewModel.summary?.sleep.score == 100)
        #expect(viewModel.summary?.activity.workoutCount == 2)
        #expect(viewModel.summary?.activity.activeDays == 2)
        #expect(viewModel.summary?.body.weightKg == 81.4)
        #expect(await snapshotService.fetchCallCount() == 1)
        #expect(await healthKitManager.requestCallCount() == 1)
    }

    @Test("reload keeps ready state when workouts fail but snapshot succeeds")
    func reloadKeepsReadyStateOnWorkoutFailure() async {
        let now = Date()
        let snapshotService = MockVisionWorkspaceSharedHealthDataService(snapshot: makeSnapshot(now: now))
        let healthKitManager = MockVisionWorkspaceHealthKitManager(isAvailable: true)
        let workoutService = MockVisionWorkspaceWorkoutService(error: MockVisionWorkspaceError.failed)
        let bodyService = MockVisionWorkspaceBodyService()
        let viewModel = VisionDashboardWorkspaceViewModel(
            sharedHealthDataService: snapshotService,
            healthKitManager: healthKitManager,
            workoutService: workoutService,
            bodyCompositionService: bodyService
        )

        await viewModel.reload()

        #expect(viewModel.loadState == .ready)
        #expect(viewModel.summary?.condition.score == 88)
        #expect(viewModel.summary?.activity.workoutCount == 0)
        #expect(viewModel.message == String(localized: "Recent workouts could not be loaded."))
    }

    @Test("reload reports unavailable when no health source is connected")
    func reloadReportsUnavailableWithoutAnyHealthSource() async {
        let healthKitManager = MockVisionWorkspaceHealthKitManager(isAvailable: false)
        let viewModel = VisionDashboardWorkspaceViewModel(
            sharedHealthDataService: nil,
            healthKitManager: healthKitManager,
            workoutService: MockVisionWorkspaceWorkoutService(),
            bodyCompositionService: MockVisionWorkspaceBodyService()
        )

        await viewModel.reload()

        #expect(
            viewModel.loadState == .unavailable(
                String(localized: "Health data isn't available in this environment.")
            )
        )
        #expect(viewModel.summary?.hasAnyData == false)
        #expect(await healthKitManager.requestCallCount() == 0)
    }

    private func makeSnapshot(now: Date) -> SharedHealthSnapshot {
        let sleepStart = Calendar.current.date(byAdding: .hour, value: -8, to: now) ?? now
        let stages = [
            SleepStage(
                stage: .deep,
                duration: 90 * 60,
                startDate: sleepStart,
                endDate: sleepStart.addingTimeInterval(90 * 60)
            ),
            SleepStage(
                stage: .rem,
                duration: 96 * 60,
                startDate: sleepStart.addingTimeInterval(90 * 60),
                endDate: sleepStart.addingTimeInterval(186 * 60)
            ),
            SleepStage(
                stage: .core,
                duration: 294 * 60,
                startDate: sleepStart.addingTimeInterval(186 * 60),
                endDate: sleepStart.addingTimeInterval(480 * 60)
            )
        ]

        return SharedHealthSnapshot(
            hrvSamples: [
                HRVSample(value: 62, date: now),
                HRVSample(value: 58, date: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now)
            ],
            todayRHR: 55,
            yesterdayRHR: 57,
            latestRHR: .init(value: 55, date: now),
            rhrCollection: [],
            todaySleepStages: stages,
            yesterdaySleepStages: [],
            latestSleepStages: .init(stages: stages, date: now),
            sleepDailyDurations: [],
            conditionScore: ConditionScore(score: 88, date: now),
            baselineStatus: BaselineStatus(daysCollected: 10, daysRequired: 14),
            recentConditionScores: [
                ConditionScore(score: 76, date: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now),
                ConditionScore(score: 88, date: now)
            ],
            failedSources: [],
            fetchedAt: now
        )
    }

    private func makeWorkouts(now: Date) -> [WorkoutSummary] {
        [
            WorkoutSummary(
                id: "strength",
                type: "Strength",
                activityType: .traditionalStrengthTraining,
                duration: 50 * 60,
                calories: 320,
                distance: nil,
                date: now
            ),
            WorkoutSummary(
                id: "run",
                type: "Running",
                activityType: .running,
                duration: 40 * 60,
                calories: 410,
                distance: 8_000,
                date: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now
            )
        ]
    }
}
