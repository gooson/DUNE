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
