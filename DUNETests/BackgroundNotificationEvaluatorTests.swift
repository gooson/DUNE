import Foundation
import HealthKit
import Testing
@testable import DUNE

private struct StepGoalResolverStepsStub: StepsQuerying {
    let todayTotal: Double?

    func fetchSteps(for date: Date) async throws -> Double? { todayTotal }
    func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchStepsCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, sum: Double)] { [] }
}

@Suite("BackgroundNotificationEvaluator")
struct BackgroundNotificationEvaluatorTests {

    @Test("Step goal uses authoritative today total instead of incremental sample sum")
    func stepGoalUsesTodayTotal() async {
        let resolver = StepGoalResolver(
            stepsService: StepGoalResolverStepsStub(todayTotal: 10_000)
        )
        let now = Date()
        let sample = HKQuantitySample(
            type: HKQuantityType(.stepCount),
            quantity: HKQuantity(unit: .count(), doubleValue: 500),
            start: now,
            end: now
        )

        let result = await resolver.evaluate(from: [sample], now: now)

        #expect(result?.type == .stepGoal)
    }

    @Test("Step goal ignores empty step payloads even when today total is cached elsewhere")
    func stepGoalIgnoresEmptyPayload() async {
        let resolver = StepGoalResolver(
            stepsService: StepGoalResolverStepsStub(todayTotal: 20_000)
        )
        let now = Date()
        let sample = HKQuantitySample(
            type: HKQuantityType(.stepCount),
            quantity: HKQuantity(unit: .count(), doubleValue: 0),
            start: now,
            end: now
        )

        let result = await resolver.evaluate(from: [sample], now: now)

        #expect(result == nil)
    }
}

private actor NotificationSleepServiceStub: SleepQuerying {
    let totalMinutes: Double?
    let shouldThrow: Bool
    private(set) var queriedDates: [Date] = []

    init(totalMinutes: Double?, shouldThrow: Bool = false) {
        self.totalMinutes = totalMinutes
        self.shouldThrow = shouldThrow
    }

    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? {
        queriedDates.append(date)
        if shouldThrow { throw CocoaError(.fileReadUnknown) }
        guard let totalMinutes else { return nil }
        return SleepSummary(totalSleepMinutes: totalMinutes, deepSleepRatio: 0.2, remSleepRatio: 0.2, date: date)
    }
    func fetchSleepStages(for date: Date) async throws -> [SleepStage] { [] }
    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? { nil }
    func fetchDailySleepDurations(start: Date, end: Date) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] { [] }
}

private actor SleepNotificationDeliverySpy: NotificationService {
    private(set) var insights: [HealthInsight] = []
    func requestAuthorization() async throws -> Bool { true }
    func isAuthorized() async -> Bool { true }
    func send(_ insight: HealthInsight) async { insights.append(insight) }
    func send(_ insight: HealthInsight, replacingIdentifier: String) async { insights.append(insight) }
}

@Suite("Sleep notification full-night query")
struct SleepNotificationResolverTests {
    @Test("Full-night total replaces an earlier partial batch in sleep debt analysis")
    func replacesPartialNight() async {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let service = NotificationSleepServiceStub(totalMinutes: 480)
        var cached = (1...7).map {
            CalculateSleepDeficitUseCase.Input.DayDuration(
                date: calendar.date(byAdding: .day, value: -$0, to: today)!, totalMinutes: 480
            )
        }
        cached.append(.init(date: today, totalMinutes: 20))
        let result = await SleepNotificationResolver(sleepService: service).evaluate(now: now, cachedDurations: cached)

        #expect(await service.queriedDates == [now])
        #expect(result?.type == .sleepComplete)
        #expect(result?.body == EvaluateHealthInsightUseCase.evaluateSleepComplete(totalMinutes: 480)?.body)
    }

    @Test("Missing or invalid full-night totals produce no notification", arguments: [nil, 0, -20, Double.nan, Double.infinity] as [Double?])
    func invalidSummaryIsIgnored(minutes: Double?) async {
        let service = NotificationSleepServiceStub(totalMinutes: minutes)
        let result = await SleepNotificationResolver(sleepService: service).evaluate()
        #expect(result == nil)
    }

    @Test("Failed full-night query does not fall back to incomplete data")
    func failedQueryIsIgnored() async {
        let service = NotificationSleepServiceStub(totalMinutes: 20, shouldThrow: true)
        let result = await SleepNotificationResolver(sleepService: service).evaluate()
        #expect(result == nil)
    }

    @Test("Sleep observer queries the full night without requiring an anchored sample")
    func observerBypassesAnchorDelta() async throws {
        let suite = "sleep-notification-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = NotificationSleepServiceStub(totalMinutes: 480)
        let delivery = SleepNotificationDeliverySpy()
        let evaluator = BackgroundNotificationEvaluator(
            store: HKHealthStore(),
            notificationService: delivery,
            settingsStore: NotificationSettingsStore(defaults: defaults),
            throttleStore: NotificationThrottleStore(defaults: defaults),
            sleepService: service
        )

        await evaluator.evaluateAndNotify(sampleType: HKCategoryType(.sleepAnalysis))

        #expect(await service.queriedDates.count == 1)
        #expect(await delivery.insights.count == 1)
    }
}
