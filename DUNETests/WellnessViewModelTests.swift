import Foundation
import Testing
@testable import DUNE

private struct NoopSleepService: SleepQuerying {
    func fetchSleepStages(for date: Date) async throws -> [SleepStage] { [] }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { nil }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] { [] }
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? { nil }
}

private struct NoopHRVService: HRVQuerying {
    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { [] }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { [] }
}

private struct NoopBodyService: BodyCompositionQuerying {
    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchBMI(for date: Date) async throws -> Double? { nil }
    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchBodyFat(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLeanBodyMass(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
}

private struct NoopVitalsService: VitalsQuerying {
    func fetchLatestSpO2(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestRespiratoryRate(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestVO2Max(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestHeartRateRecovery(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestWristTemperature(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchSpO2Collection(days: Int) async throws -> [VitalSample] { [] }
    func fetchRespiratoryRateCollection(days: Int) async throws -> [VitalSample] { [] }
    func fetchVO2MaxHistory(days: Int) async throws -> [VitalSample] { [] }
    func fetchHeartRateRecoveryHistory(days: Int) async throws -> [VitalSample] { [] }
    func fetchWristTemperatureCollection(days: Int) async throws -> [VitalSample] { [] }
    func fetchSpO2Collection(start: Date, end: Date) async throws -> [VitalSample] { [] }
    func fetchRespiratoryRateCollection(start: Date, end: Date) async throws -> [VitalSample] { [] }
    func fetchVO2MaxHistory(start: Date, end: Date) async throws -> [VitalSample] { [] }
    func fetchHeartRateRecoveryHistory(start: Date, end: Date) async throws -> [VitalSample] { [] }
    func fetchWristTemperatureCollection(start: Date, end: Date) async throws -> [VitalSample] { [] }
    func fetchWristTemperatureBaseline(days: Int) async throws -> Double? { nil }
}

private struct VO2FreshnessVitalsService: VitalsQuerying {
    let latest: VitalSample?
    let history: [VitalSample]

    func fetchLatestSpO2(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestRespiratoryRate(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestVO2Max(withinDays days: Int) async throws -> VitalSample? { latest }
    func fetchLatestHeartRateRecovery(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchLatestWristTemperature(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchSpO2Collection(days: Int) async throws -> [VitalSample] { [] }
    func fetchRespiratoryRateCollection(days: Int) async throws -> [VitalSample] { [] }
    func fetchVO2MaxHistory(days: Int) async throws -> [VitalSample] { history }
    func fetchHeartRateRecoveryHistory(days: Int) async throws -> [VitalSample] { [] }
    func fetchWristTemperatureCollection(days: Int) async throws -> [VitalSample] { [] }
    func fetchSpO2Collection(start: Date, end: Date) async throws -> [VitalSample] { [] }
    func fetchRespiratoryRateCollection(start: Date, end: Date) async throws -> [VitalSample] { [] }
    func fetchVO2MaxHistory(start: Date, end: Date) async throws -> [VitalSample] { history }
    func fetchHeartRateRecoveryHistory(start: Date, end: Date) async throws -> [VitalSample] { [] }
    func fetchWristTemperatureCollection(start: Date, end: Date) async throws -> [VitalSample] { [] }
    func fetchWristTemperatureBaseline(days: Int) async throws -> Double? { nil }
}

private struct NoopHeartRateService: HeartRateQuerying {
    func fetchHeartRateSamples(forWorkoutID workoutID: String) async throws -> [HeartRateSample] { [] }
    func fetchHeartRateSummary(forWorkoutID workoutID: String) async throws -> HeartRateSummary {
        HeartRateSummary(average: 0, max: 0, min: 0, samples: [])
    }
    func fetchLatestHeartRate(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchHeartRateHistory(days: Int) async throws -> [VitalSample] { [] }
    func fetchHeartRateHistory(start: Date, end: Date) async throws -> [VitalSample] { [] }
    func fetchHeartRateZones(forWorkoutID workoutID: String, maxHR: Double) async throws -> [HeartRateZone] { [] }
}

private actor MockSharedHealthDataService: SharedHealthDataService {
    private let snapshot: SharedHealthSnapshot

    init(snapshot: SharedHealthSnapshot) {
        self.snapshot = snapshot
    }

    func fetchSnapshot() async -> SharedHealthSnapshot { snapshot }
    func invalidateCache() async {}
}

private actor SuspendingWellnessSharedHealthDataService: SharedHealthDataService {
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

private actor StartupTrackingBodyService: BodyCompositionQuerying {
    private(set) var fetchCallCount = 0

    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] {
        fetchCallCount += 1
        return []
    }

    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] {
        fetchCallCount += 1
        return []
    }

    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] {
        fetchCallCount += 1
        return []
    }

    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        fetchCallCount += 1
        return []
    }

    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        fetchCallCount += 1
        return nil
    }

    func fetchBMI(for date: Date) async throws -> Double? {
        fetchCallCount += 1
        return nil
    }

    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        fetchCallCount += 1
        return nil
    }

    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        fetchCallCount += 1
        return []
    }

    func fetchBodyFat(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        fetchCallCount += 1
        return []
    }

    func fetchLeanBodyMass(start: Date, end: Date) async throws -> [BodyCompositionSample] {
        fetchCallCount += 1
        return []
    }

    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        fetchCallCount += 1
        return nil
    }

    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)? {
        fetchCallCount += 1
        return nil
    }
}

private actor TodayPreferredBMIBodyService: BodyCompositionQuerying {
    let todayBMI: Double?
    let latestBMI: (value: Double, date: Date)?

    init(todayBMI: Double?, latestBMI: (value: Double, date: Date)?) {
        self.todayBMI = todayBMI
        self.latestBMI = latestBMI
    }

    func fetchWeight(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchBodyFat(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchLeanBodyMass(days: Int) async throws -> [BodyCompositionSample] { [] }
    func fetchWeight(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLatestWeight(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchBMI(for date: Date) async throws -> Double? { todayBMI }
    func fetchLatestBMI(withinDays days: Int) async throws -> (value: Double, date: Date)? { latestBMI }
    func fetchBMI(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchBodyFat(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLeanBodyMass(start: Date, end: Date) async throws -> [BodyCompositionSample] { [] }
    func fetchLatestBodyFat(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchLatestLeanBodyMass(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
}

private func makeEmptyWellnessSharedSnapshot(fetchedAt: Date = Date()) -> SharedHealthSnapshot {
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

@Suite("WellnessViewModel")
@MainActor
struct WellnessViewModelTests {

    @Test("Shared snapshot keeps sleep sparkline at 7 points with zero-filled gaps")
    func sharedSnapshotSleepSparklineHasSevenPoints() async {
        let calendar = Calendar.current
        let now = Date()
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: now) ?? now
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) ?? now

        let snapshot = SharedHealthSnapshot(
            hrvSamples: [HRVSample(value: 52, date: now)],
            todayRHR: 58,
            yesterdayRHR: 60,
            latestRHR: nil,
            rhrCollection: [],
            todaySleepStages: [
                SleepStage(stage: .core, duration: 6 * 60 * 60, startDate: now, endDate: now)
            ],
            yesterdaySleepStages: [],
            latestSleepStages: nil,
            sleepDailyDurations: [
                .init(date: fiveDaysAgo, totalMinutes: 420, stageBreakdown: [:]),
                .init(date: twoDaysAgo, totalMinutes: 360, stageBreakdown: [:])
            ],
            conditionScore: ConditionScore(score: 72, date: now),
            baselineStatus: BaselineStatus(daysCollected: 7, daysRequired: 7),
            recentConditionScores: [],
            failedSources: [],
            fetchedAt: now
        )

        let vm = WellnessViewModel(
            sleepService: NoopSleepService(),
            bodyService: NoopBodyService(),
            hrvService: NoopHRVService(),
            vitalsService: NoopVitalsService(),
            heartRateService: NoopHeartRateService(),
            sharedHealthDataService: MockSharedHealthDataService(snapshot: snapshot)
        )

        await vm.performRefresh()

        let sleepCard = vm.activeCards.first { $0.category == .sleep }
        #expect(sleepCard != nil)
        #expect(sleepCard?.sparklineData.count == 7)
        #expect((sleepCard?.sparklineData.filter { $0 == 0 }.count ?? 0) >= 4)
    }

    @Test("Condition score is sourced from shared snapshot")
    func sharedSnapshotConditionScoreIsUsed() async {
        let now = Date()
        let sharedCondition = ConditionScore(score: 68, date: now)

        let snapshot = SharedHealthSnapshot(
            hrvSamples: [],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: nil,
            rhrCollection: [],
            todaySleepStages: [
                SleepStage(stage: .core, duration: 5 * 60 * 60, startDate: now, endDate: now)
            ],
            yesterdaySleepStages: [],
            latestSleepStages: nil,
            sleepDailyDurations: [],
            conditionScore: sharedCondition,
            baselineStatus: BaselineStatus(daysCollected: 7, daysRequired: 7),
            recentConditionScores: [],
            failedSources: [],
            fetchedAt: now
        )

        let vm = WellnessViewModel(
            sleepService: NoopSleepService(),
            bodyService: NoopBodyService(),
            hrvService: NoopHRVService(),
            vitalsService: NoopVitalsService(),
            heartRateService: NoopHeartRateService(),
            sharedHealthDataService: MockSharedHealthDataService(snapshot: snapshot)
        )

        await vm.performRefresh()

        #expect(vm.conditionScore == sharedCondition.score)
        #expect(vm.conditionScoreFull?.score == sharedCondition.score)
    }

    @Test("Body fetch starts before shared snapshot resolves")
    func bodyFetchStartsBeforeSharedSnapshotCompletes() async {
        let sharedService = SuspendingWellnessSharedHealthDataService(
            snapshot: makeEmptyWellnessSharedSnapshot()
        )
        let bodyService = StartupTrackingBodyService()
        let vm = WellnessViewModel(
            sleepService: NoopSleepService(),
            bodyService: bodyService,
            hrvService: NoopHRVService(),
            vitalsService: NoopVitalsService(),
            heartRateService: NoopHeartRateService(),
            sharedHealthDataService: sharedService
        )

        let loadTask = Task {
            await vm.performRefresh()
        }

        await sharedService.waitUntilFetchStarts()
        try? await Task.sleep(for: .milliseconds(20))

        #expect(await bodyService.fetchCallCount > 0)

        await sharedService.resumeFetch()
        await loadTask.value
    }

    @Test("VO2 card prefers freshest history sample when latest query is older")
    func vo2CardUsesFreshestSampleAcrossQueries() async {
        let now = Date()
        let older = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let newer = Calendar.current.date(byAdding: .hour, value: -2, to: now) ?? now

        let vm = WellnessViewModel(
            sleepService: NoopSleepService(),
            bodyService: NoopBodyService(),
            hrvService: NoopHRVService(),
            vitalsService: VO2FreshnessVitalsService(
                latest: VitalSample(value: 41.2, date: older),
                history: [
                    VitalSample(value: 41.2, date: older),
                    VitalSample(value: 43.7, date: newer)
                ]
            ),
            heartRateService: NoopHeartRateService(),
            sharedHealthDataService: MockSharedHealthDataService(snapshot: makeEmptyWellnessSharedSnapshot())
        )

        await vm.performRefresh()
      
        let vo2Card = vm.activeCards.first { $0.category == .vo2Max }
        #expect(vo2Card != nil)
        #expect(vo2Card?.metric.value == 43.7)
        #expect(vo2Card?.lastUpdated == newer)
    }

    @Test("BMI card prefers today's measurement over older latest sample")
    func bmiCardPrefersTodayMeasurement() async {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let bodyService = TodayPreferredBMIBodyService(
            todayBMI: 24.6,
            latestBMI: (value: 23.9, date: weekAgo)
        )

        let vm = WellnessViewModel(
            sleepService: NoopSleepService(),
            bodyService: bodyService,
            hrvService: NoopHRVService(),
            vitalsService: NoopVitalsService(),
            heartRateService: NoopHeartRateService(),
            sharedHealthDataService: MockSharedHealthDataService(snapshot: makeEmptyWellnessSharedSnapshot())
        )

        await vm.performRefresh()

        let bmiCard = vm.physicalCards.first(where: { $0.category == .bmi })
        #expect(bmiCard != nil)
        #expect(bmiCard?.value == "24.6")
        #expect(bmiCard?.lastUpdated.daysAgo == 0)
    }
}
