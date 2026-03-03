import Foundation
import Testing
@testable import DUNE

@Suite("NotificationThrottleStore")
struct NotificationThrottleStoreTests {

    // MARK: - Helpers

    private func makeStore(
        dailyBudgetLimit: Int = 6,
        dedupWindowSeconds: TimeInterval = 60 * 60
    ) -> NotificationThrottleStore {
        let defaults = UserDefaults(suiteName: "test.throttle.\(UUID().uuidString)")!
        return NotificationThrottleStore(
            defaults: defaults,
            dailyBudgetLimit: dailyBudgetLimit,
            dedupWindowSeconds: dedupWindowSeconds
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
}
