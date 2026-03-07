import Foundation
import Testing
@testable import DUNE

private actor MockSpatialSharedHealthDataService: SharedHealthDataService {
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

private actor MockSpatialHealthKitManager: HealthKitManaging {
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

private actor MockSpatialHeartRateService: HeartRateQuerying {
    private var fetchLatestCount = 0

    func fetchHeartRateSamples(forWorkoutID workoutID: String) async throws -> [HeartRateSample] {
        []
    }

    func fetchHeartRateSummary(forWorkoutID workoutID: String) async throws -> HeartRateSummary {
        HeartRateSummary(average: 0, max: 0, min: 0, samples: [])
    }

    func fetchLatestHeartRate(withinDays days: Int) async throws -> VitalSample? {
        fetchLatestCount += 1
        return nil
    }

    func fetchHeartRateHistory(days: Int) async throws -> [VitalSample] {
        []
    }

    func fetchHeartRateZones(
        forWorkoutID workoutID: String,
        maxHR: Double
    ) async throws -> [HeartRateZone] {
        []
    }

    func fetchLatestCallCount() -> Int {
        fetchLatestCount
    }
}

private actor MockSpatialWorkoutService: WorkoutQuerying {
    private var fetchWorkoutsCount = 0

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        fetchWorkoutsCount += 1
        return []
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        fetchWorkoutsCount += 1
        return []
    }

    func fetchCallCount() -> Int {
        fetchWorkoutsCount
    }
}

@Suite("VisionSpatialViewModel")
@MainActor
struct VisionSpatialViewModelTests {
    @Test("reload uses mirrored snapshot data when HealthKit is unavailable")
    func reloadUsesMirroredSnapshotFallback() async {
        let snapshotService = MockSpatialSharedHealthDataService(
            snapshot: makeSnapshot(latestRHR: 54.0)
        )
        let healthKitManager = MockSpatialHealthKitManager(isAvailable: false)
        let heartRateService = MockSpatialHeartRateService()
        let workoutService = MockSpatialWorkoutService()
        let viewModel = VisionSpatialViewModel(
            sharedHealthDataService: snapshotService,
            healthKitManager: healthKitManager,
            heartRateService: heartRateService,
            workoutService: workoutService
        )

        await viewModel.reload()

        #expect(viewModel.loadState == .ready)
        #expect(viewModel.summary?.heartRateOrb.baselineRHR == 54.0)
        #expect(viewModel.summary?.heartRateOrb.currentBPM == nil)
        #expect(viewModel.summary?.hasAnyData == true)
        #expect(await snapshotService.fetchCallCount() == 1)
        #expect(await healthKitManager.requestCallCount() == 0)
        #expect(await heartRateService.fetchLatestCallCount() == 0)
        #expect(await workoutService.fetchCallCount() == 0)
    }

    @Test("reload reports unavailable when neither HealthKit nor shared snapshot is connected")
    func reloadReportsUnavailableWithoutAnyHealthSource() async {
        let healthKitManager = MockSpatialHealthKitManager(isAvailable: false)
        let heartRateService = MockSpatialHeartRateService()
        let workoutService = MockSpatialWorkoutService()
        let viewModel = VisionSpatialViewModel(
            sharedHealthDataService: nil,
            healthKitManager: healthKitManager,
            heartRateService: heartRateService,
            workoutService: workoutService
        )

        await viewModel.reload()

        #expect(
            viewModel.loadState == .unavailable(
                String(localized: "Health data isn't available in this environment.")
            )
        )
        #expect(viewModel.summary?.hasAnyData == false)
        #expect(await healthKitManager.requestCallCount() == 0)
        #expect(await heartRateService.fetchLatestCallCount() == 0)
        #expect(await workoutService.fetchCallCount() == 0)
    }

    private func makeSnapshot(latestRHR: Double) -> SharedHealthSnapshot {
        SharedHealthSnapshot(
            hrvSamples: [],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: .init(
                value: latestRHR,
                date: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            rhrCollection: [],
            todaySleepStages: [],
            yesterdaySleepStages: [],
            latestSleepStages: nil,
            sleepDailyDurations: [],
            conditionScore: nil,
            baselineStatus: nil,
            recentConditionScores: [],
            failedSources: [],
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
