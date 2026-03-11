import Foundation
import Testing
@testable import DUNE

private actor MockQASharedHealthDataService: SharedHealthDataService {
    private let snapshot: SharedHealthSnapshot

    init(snapshot: SharedHealthSnapshot) {
        self.snapshot = snapshot
    }

    func fetchSnapshot() async -> SharedHealthSnapshot { snapshot }
    func invalidateCache() async {}
}

private struct MockQASleepService: SleepQuerying {
    var durations: [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] = []
    var requestEvaluator: (@Sendable (Date, Date) -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])])?

    func fetchSleepStages(for date: Date) async throws -> [SleepStage] { [] }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { nil }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] {
        if let requestEvaluator {
            return requestEvaluator(start, end)
        }
        return durations
    }
    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? { nil }
}

private struct MockQAWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { workouts }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] { workouts }
}

private struct MockQAHRVService: HRVQuerying {
    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { [] }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { [] }
}

@Suite("HealthDataQAService")
struct HealthDataQAServiceTests {
    @Test("Baseline summary includes condition sleep and HRV context")
    func baselineSummaryIncludesCoreMetrics() async {
        let now = Date(timeIntervalSince1970: 1_741_478_400)
        let snapshot = makeSnapshot(referenceDate: now)
        let service = HealthDataQAService(
            sharedHealthDataService: MockQASharedHealthDataService(snapshot: snapshot),
            sleepService: MockQASleepService(),
            workoutService: MockQAWorkoutService(),
            hrvService: MockQAHRVService(),
            nowProvider: { now }
        )

        let summary = await service.makeBaselineSummary()

        #expect(summary.contains("Current condition: 68/100"))
        #expect(summary.contains("7-day sleep average"))
        #expect(summary.contains("14-day HRV average"))
        #expect(summary.contains("Resting heart rate"))
    }

    @Test("Condition summary includes trend and HRV baseline context")
    func conditionSummaryIncludesTrend() async {
        let now = Date(timeIntervalSince1970: 1_741_478_400)
        let snapshot = makeSnapshot(referenceDate: now)
        let service = HealthDataQAService(
            sharedHealthDataService: MockQASharedHealthDataService(snapshot: snapshot),
            sleepService: MockQASleepService(),
            workoutService: MockQAWorkoutService(),
            hrvService: MockQAHRVService(),
            nowProvider: { now }
        )

        let summary = await service.makeConditionSummary(days: 7)

        #expect(summary.contains("Condition summary for the last 7 days"))
        #expect(summary.contains("Current score: 68/100"))
        #expect(summary.contains("HRV is"))
        #expect(summary.contains("Trend:"))
    }

    @Test("Workout summary includes session count and top activity types")
    func workoutSummaryIncludesTopActivities() async {
        let now = Date(timeIntervalSince1970: 1_741_478_400)
        let snapshot = makeSnapshot(referenceDate: now)
        let workouts = [
            WorkoutSummary(id: "1", type: "Strength Training", duration: 3_000, calories: 320, distance: nil, date: now.addingTimeInterval(-86_400 * 2)),
            WorkoutSummary(id: "2", type: "Run", duration: 1_800, calories: 240, distance: 4_200, date: now.addingTimeInterval(-86_400)),
            WorkoutSummary(id: "3", type: "Strength Training", duration: 2_400, calories: 280, distance: nil, date: now)
        ]
        let service = HealthDataQAService(
            sharedHealthDataService: MockQASharedHealthDataService(snapshot: snapshot),
            sleepService: MockQASleepService(),
            workoutService: MockQAWorkoutService(workouts: workouts),
            hrvService: MockQAHRVService(),
            nowProvider: { now }
        )

        let summary = await service.makeWorkoutSummary(days: 14)

        #expect(summary.contains("Sessions: 3"))
        #expect(summary.contains("Top activity types: Strength Training x2, Run x1"))
        #expect(summary.contains("Total active calories: 840 kcal"))
    }

    @Test("Recovery summary highlights sleep and resting heart rate penalty")
    func recoverySummaryHighlightsFactors() async {
        let now = Date(timeIntervalSince1970: 1_741_478_400)
        let snapshot = makeSnapshot(referenceDate: now)
        let service = HealthDataQAService(
            sharedHealthDataService: MockQASharedHealthDataService(snapshot: snapshot),
            sleepService: MockQASleepService(),
            workoutService: MockQAWorkoutService(),
            hrvService: MockQAHRVService(),
            nowProvider: { now }
        )

        let summary = await service.makeRecoverySummary(days: 7)

        #expect(summary.contains("Recovery factors:"))
        #expect(summary.contains("condition is 68/100"))
        #expect(summary.contains("penalty"))
        #expect(summary.contains("Average sleep over 7 days"))
    }

    @Test("Asking on simulator falls back when Foundation Models are unavailable")
    func askFallsBackWhenUnavailable() async {
        let now = Date(timeIntervalSince1970: 1_741_478_400)
        let snapshot = makeSnapshot(referenceDate: now)
        let service = HealthDataQAService(
            sharedHealthDataService: MockQASharedHealthDataService(snapshot: snapshot),
            sleepService: MockQASleepService(),
            workoutService: MockQAWorkoutService(),
            hrvService: MockQAHRVService(),
            nowProvider: { now }
        )

        let reply = await service.ask("How did I sleep this week?")

        #expect(reply.isFallback)
        #expect(reply.text.contains("Health Q&A requires Apple Intelligence") || HealthDataQAService.isAvailable)
    }

    @Test("Sleep summary live fallback includes the current day window")
    func sleepSummaryFallbackIncludesCurrentDayWindow() async {
        let now = Date(timeIntervalSince1970: 1_741_478_400)
        let calendar = Calendar.current
        let expectedDate = calendar.startOfDay(for: now)
        let sleepService = MockQASleepService(
            requestEvaluator: { start, end in
                let requestedDays = Calendar.current.dateComponents([.day], from: start, to: end).day
                guard requestedDays == 1 else { return [] }
                return [(date: expectedDate, totalMinutes: 435, stageBreakdown: [:])]
            }
        )
        let service = HealthDataQAService(
            sharedHealthDataService: nil,
            sleepService: sleepService,
            workoutService: MockQAWorkoutService(),
            hrvService: MockQAHRVService(),
            nowProvider: { now }
        )

        let summary = await service.makeSleepSummary(days: 1)

        #expect(summary.contains("Sleep summary for the last 1 days"))
        #expect(summary.contains("Last recorded sleep: 7h 15m"))
    }

    private func makeSnapshot(referenceDate: Date) -> SharedHealthSnapshot {
        let calendar = Calendar.current
        let detail = ConditionScoreDetail(
            todayHRV: 52,
            baselineHRV: 58,
            zScore: -0.8,
            stdDev: 0.16,
            effectiveStdDev: 0.16,
            daysInBaseline: 14,
            todayDate: referenceDate,
            rawScore: 68,
            rhrPenalty: 6.5,
            todayRHR: 72,
            yesterdayRHR: 65
        )

        return SharedHealthSnapshot(
            hrvSamples: [
                HRVSample(value: 52, date: referenceDate),
                HRVSample(value: 57, date: calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate),
                HRVSample(value: 59, date: calendar.date(byAdding: .day, value: -2, to: referenceDate) ?? referenceDate)
            ],
            todayRHR: 57,
            yesterdayRHR: 55,
            latestRHR: SharedHealthSnapshot.RHRSample(value: 57, date: referenceDate),
            rhrCollection: [
                (calendar.date(byAdding: .day, value: -2, to: referenceDate) ?? referenceDate, 54, 58, 56),
                (calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate, 55, 59, 57)
            ],
            todaySleepStages: [],
            yesterdaySleepStages: [],
            latestSleepStages: nil,
            sleepDailyDurations: [
                SharedHealthSnapshot.SleepDailyDuration(
                    date: calendar.date(byAdding: .day, value: -2, to: referenceDate) ?? referenceDate,
                    totalMinutes: 380,
                    stageBreakdown: [:]
                ),
                SharedHealthSnapshot.SleepDailyDuration(
                    date: calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate,
                    totalMinutes: 410,
                    stageBreakdown: [:]
                ),
                SharedHealthSnapshot.SleepDailyDuration(
                    date: referenceDate,
                    totalMinutes: 435,
                    stageBreakdown: [:]
                )
            ],
            conditionScore: ConditionScore(score: 68, date: referenceDate, contributions: [], detail: detail),
            baselineStatus: BaselineStatus(daysCollected: 14, daysRequired: 14),
            recentConditionScores: [
                ConditionScore(score: 62, date: calendar.date(byAdding: .day, value: -2, to: referenceDate) ?? referenceDate),
                ConditionScore(score: 65, date: calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate)
            ],
            failedSources: [],
            fetchedAt: referenceDate
        )
    }
}
