import Foundation
import Testing
@testable import Dailve

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
    func fetchWristTemperatureBaseline(days: Int) async throws -> Double? { nil }
}

private struct NoopHeartRateService: HeartRateQuerying {
    func fetchHeartRateSamples(forWorkoutID workoutID: String) async throws -> [HeartRateSample] { [] }
    func fetchHeartRateSummary(forWorkoutID workoutID: String) async throws -> HeartRateSummary {
        HeartRateSummary(average: 0, max: 0, min: 0, samples: [])
    }
    func fetchLatestHeartRate(withinDays days: Int) async throws -> VitalSample? { nil }
    func fetchHeartRateHistory(days: Int) async throws -> [VitalSample] { [] }
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
}
