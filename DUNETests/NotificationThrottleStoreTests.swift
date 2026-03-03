import Foundation
import Testing
@testable import DUNE

@Suite("NotificationThrottleStore")
struct NotificationThrottleStoreTests {

    // MARK: - Helpers

    private func makeStore() -> NotificationThrottleStore {
        let defaults = UserDefaults(suiteName: "test.throttle.\(UUID().uuidString)")!
        return NotificationThrottleStore(defaults: defaults)
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
}
