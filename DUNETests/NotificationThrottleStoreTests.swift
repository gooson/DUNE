import Foundation
import Testing
@testable import DUNE

@Suite("NotificationThrottleStore")
struct NotificationThrottleStoreTests {

    // MARK: - Helpers

    private func makeStore(
        dailyBudgetLimit: Int = 6,
        dedupWindowSeconds: TimeInterval = 60 * 60,
        bodyCompositionMergeWindowSeconds: TimeInterval = 60 * 5,
        bodyCompositionDebounceSeconds: TimeInterval = 3
    ) -> NotificationThrottleStore {
        let defaults = UserDefaults(suiteName: "test.throttle.\(UUID().uuidString)")!
        return NotificationThrottleStore(
            defaults: defaults,
            dailyBudgetLimit: dailyBudgetLimit,
            dedupWindowSeconds: dedupWindowSeconds,
            bodyCompositionMergeWindowSeconds: bodyCompositionMergeWindowSeconds,
            bodyCompositionDebounceSeconds: bodyCompositionDebounceSeconds
        )
    }

    private func makeInsight(
        type: HealthInsight.InsightType,
        title: String,
        body: String,
        severity: HealthInsight.Severity,
        route: NotificationRoute? = nil
    ) -> HealthInsight {
        HealthInsight(
            type: type,
            title: title,
            body: body,
            severity: severity,
            route: route
        )
    }

    // MARK: - canSend

    @Test("canSend returns true when never sent before")
    func canSendFirstTime() {
        let store = makeStore()
        #expect(store.canSend(for: .hrvAnomaly) == true)
    }

    @Test("canSend returns false after recording send on same day")
    func canSendAfterRecordSameDay() {
        let store = makeStore()
        store.recordSent(for: .hrvAnomaly)
        #expect(store.canSend(for: .hrvAnomaly) == false)
    }

    @Test("workoutPR is never throttled")
    func workoutPRNeverThrottled() {
        let store = makeStore()
        store.recordSent(for: .workoutPR)
        #expect(store.canSend(for: .workoutPR) == true)
    }

    @Test("Different types are independent")
    func differentTypesIndependent() {
        let store = makeStore()
        store.recordSent(for: .hrvAnomaly)
        #expect(store.canSend(for: .rhrAnomaly) == true)
        #expect(store.canSend(for: .stepGoal) == true)
    }

    // MARK: - reset

    @Test("reset clears throttle for specific type")
    func resetClearsThrottle() {
        let store = makeStore()
        store.recordSent(for: .stepGoal)
        #expect(store.canSend(for: .stepGoal) == false)
        store.reset(for: .stepGoal)
        #expect(store.canSend(for: .stepGoal) == true)
    }

    // MARK: - insight-level policy

    @Test("Identical insight is deduplicated within one hour")
    func dedupWithinWindow() {
        let store = makeStore(dedupWindowSeconds: 60 * 60)
        let base = Date(timeIntervalSince1970: 1_000)
        let insight = makeInsight(
            type: .workoutPR,
            title: "New PR",
            body: "Bench Press",
            severity: .celebration,
            route: .workoutDetail(workoutID: "workout-1")
        )

        #expect(store.canSend(insight: insight, now: base) == true)
        store.recordSent(insight: insight, now: base)
        #expect(store.canSend(insight: insight, now: base.addingTimeInterval(60 * 30)) == false)
        #expect(store.canSend(insight: insight, now: base.addingTimeInterval(60 * 61)) == true)
    }

    @Test("Informational alerts respect daily budget")
    func informationalBudgetLimit() {
        let store = makeStore(dailyBudgetLimit: 2, dedupWindowSeconds: 0)
        let now = Date(timeIntervalSince1970: 10_000)

        let first = makeInsight(
            type: .sleepComplete,
            title: "Sleep Recorded",
            body: "7h 12m",
            severity: .informational
        )
        let second = makeInsight(
            type: .weightUpdate,
            title: "Weight Updated",
            body: "73.2kg",
            severity: .informational
        )
        let third = makeInsight(
            type: .bodyFatUpdate,
            title: "Body Fat Updated",
            body: "18.4%",
            severity: .informational
        )

        #expect(store.canSend(insight: first, now: now) == true)
        store.recordSent(insight: first, now: now)
        #expect(store.canSend(insight: second, now: now) == true)
        store.recordSent(insight: second, now: now)
        #expect(store.canSend(insight: third, now: now) == false)
    }

    @Test("Attention severity bypasses informational daily budget")
    func attentionBypassesBudget() {
        let store = makeStore(dailyBudgetLimit: 1, dedupWindowSeconds: 0)
        let now = Date(timeIntervalSince1970: 20_000)

        let informational = makeInsight(
            type: .sleepComplete,
            title: "Sleep Recorded",
            body: "6h 40m",
            severity: .informational
        )
        let attention = makeInsight(
            type: .hrvAnomaly,
            title: "HRV Alert",
            body: "Down 22%",
            severity: .attention
        )

        #expect(store.canSend(insight: informational, now: now) == true)
        store.recordSent(insight: informational, now: now)
        #expect(store.canSend(insight: attention, now: now) == true)
    }

    @Test("shouldSendAndRecord performs atomic check-and-record")
    func shouldSendAndRecordAtomicFlow() {
        let store = makeStore(dedupWindowSeconds: 60 * 60)
        let base = Date(timeIntervalSince1970: 30_000)
        let insight = makeInsight(
            type: .workoutPR,
            title: "New PR",
            body: "Deadlift",
            severity: .celebration,
            route: .workoutDetail(workoutID: "workout-2")
        )

        #expect(store.shouldSendAndRecord(insight: insight, now: base) == true)
        #expect(store.shouldSendAndRecord(insight: insight, now: base.addingTimeInterval(60)) == false)
    }

    @Test("Body composition updates inside merge window are collapsed into one alert")
    func bodyCompositionUpdatesAreCollapsedWithinMergeWindow() {
        let store = makeStore(dedupWindowSeconds: 0, bodyCompositionMergeWindowSeconds: 60 * 5)
        let base = Date(timeIntervalSince1970: 40_000)

        let weight = makeInsight(
            type: .weightUpdate,
            title: "Weight Recorded",
            body: "73.2kg",
            severity: .informational
        )
        let bodyFat = makeInsight(
            type: .bodyFatUpdate,
            title: "Body Fat Recorded",
            body: "18.4%",
            severity: .informational
        )

        #expect(store.shouldSendAndRecord(insight: weight, now: base) == true)
        #expect(store.shouldSendAndRecord(insight: bodyFat, now: base.addingTimeInterval(60)) == false)
    }

    @Test("Body composition updates can be sent again after merge window")
    func bodyCompositionUpdatesCanSendAfterMergeWindow() {
        let store = makeStore(dedupWindowSeconds: 0, bodyCompositionMergeWindowSeconds: 60 * 5)
        let base = Date(timeIntervalSince1970: 50_000)

        let weight = makeInsight(
            type: .weightUpdate,
            title: "Weight Recorded",
            body: "73.2kg",
            severity: .informational
        )
        let bmi = makeInsight(
            type: .bmiUpdate,
            title: "BMI Updated",
            body: "22.1",
            severity: .informational
        )

        #expect(store.shouldSendAndRecord(insight: weight, now: base) == true)
        #expect(store.shouldSendAndRecord(insight: bmi, now: base.addingTimeInterval(60 * 6)) == true)
    }

    // MARK: - Body Composition Debounce (buffer + claim pattern)

    @Test("Buffer then claim returns merged body with all buffered values")
    func bufferThenClaimReturnsMergedBody() {
        let store = makeStore(dedupWindowSeconds: 0, bodyCompositionMergeWindowSeconds: 60 * 5)
        let base = Date(timeIntervalSince1970: 60_000)

        // Simulate 3 concurrent HKObserverQuery callbacks buffering values
        store.bufferBodyCompositionValue(type: .weightUpdate, formattedValue: "73.2kg", now: base)
        store.bufferBodyCompositionValue(type: .bodyFatUpdate, formattedValue: "18.4%", now: base.addingTimeInterval(0.1))
        store.bufferBodyCompositionValue(type: .bmiUpdate, formattedValue: "BMI: 22.1", now: base.addingTimeInterval(0.2))

        // After debounce delay, first claim wins
        let result = store.claimAndBuildMergedBody(now: base.addingTimeInterval(2))
        #expect(result != nil)
        #expect(result!.contains("73.2kg"))
        #expect(result!.contains("18.4%"))
        #expect(result!.contains("BMI: 22.1"))
    }

    @Test("Second claim within debounce window returns nil")
    func secondClaimWithinDebounceReturnsNil() {
        let store = makeStore(
            dedupWindowSeconds: 0,
            bodyCompositionMergeWindowSeconds: 60 * 5,
            bodyCompositionDebounceSeconds: 3
        )
        let base = Date(timeIntervalSince1970: 70_000)

        store.bufferBodyCompositionValue(type: .weightUpdate, formattedValue: "73.2kg", now: base)
        store.bufferBodyCompositionValue(type: .bodyFatUpdate, formattedValue: "18.4%", now: base.addingTimeInterval(0.1))

        // First claim succeeds
        let first = store.claimAndBuildMergedBody(now: base.addingTimeInterval(2))
        #expect(first != nil)

        // Second claim within debounce window (3s) fails
        let second = store.claimAndBuildMergedBody(now: base.addingTimeInterval(2.5))
        #expect(second == nil)
    }

    @Test("Claim after debounce window expires succeeds again")
    func claimAfterDebounceWindowSucceeds() {
        let store = makeStore(
            dedupWindowSeconds: 0,
            bodyCompositionMergeWindowSeconds: 60 * 5,
            bodyCompositionDebounceSeconds: 3
        )
        let base = Date(timeIntervalSince1970: 80_000)

        store.bufferBodyCompositionValue(type: .weightUpdate, formattedValue: "73.2kg", now: base)

        let first = store.claimAndBuildMergedBody(now: base.addingTimeInterval(2))
        #expect(first != nil)

        // Buffer new value and claim after debounce window
        store.bufferBodyCompositionValue(type: .weightUpdate, formattedValue: "74.0kg", now: base.addingTimeInterval(4))
        let second = store.claimAndBuildMergedBody(now: base.addingTimeInterval(6))
        #expect(second != nil)
        #expect(second!.contains("74.0kg"))
    }

    @Test("Single body composition value is sent after debounce")
    func singleBodyCompositionValueSentAfterDebounce() {
        let store = makeStore(dedupWindowSeconds: 0, bodyCompositionMergeWindowSeconds: 60 * 5)
        let base = Date(timeIntervalSince1970: 90_000)

        // Only weight recorded (no bodyFat or BMI)
        store.bufferBodyCompositionValue(type: .weightUpdate, formattedValue: "73.2kg", now: base)

        let result = store.claimAndBuildMergedBody(now: base.addingTimeInterval(2))
        #expect(result == "73.2kg")
    }

    @Test("Claim records per-type throttle for all buffered types")
    func claimRecordsPerTypeThrottle() {
        let store = makeStore(dedupWindowSeconds: 0, bodyCompositionMergeWindowSeconds: 60 * 5)
        let base = Date(timeIntervalSince1970: 100_000)

        store.bufferBodyCompositionValue(type: .weightUpdate, formattedValue: "73.2kg", now: base)
        store.bufferBodyCompositionValue(type: .bmiUpdate, formattedValue: "22.1", now: base.addingTimeInterval(0.1))

        _ = store.claimAndBuildMergedBody(now: base.addingTimeInterval(2))

        // Both types should now be throttled for today
        #expect(store.canSend(for: .weightUpdate, now: base.addingTimeInterval(3)) == false)
        #expect(store.canSend(for: .bmiUpdate, now: base.addingTimeInterval(3)) == false)
    }
}
