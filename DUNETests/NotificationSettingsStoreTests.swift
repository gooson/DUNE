import Foundation
import Testing
@testable import DUNE

@Suite("NotificationSettingsStore")
struct NotificationSettingsStoreTests {

    // MARK: - Helpers

    private func makeStore() -> NotificationSettingsStore {
        let defaults = UserDefaults(suiteName: "test.notifSettings.\(UUID().uuidString)")!
        return NotificationSettingsStore(defaults: defaults)
    }

    // MARK: - Defaults

    @Test("All types enabled by default")
    func allEnabledByDefault() {
        let store = makeStore()
        for type in HealthInsight.InsightType.allCases {
            #expect(store.isEnabled(for: type) == true)
        }
    }

    @Test("hasAnyEnabled returns true by default")
    func hasAnyEnabledDefault() {
        let store = makeStore()
        #expect(store.hasAnyEnabled == true)
    }

    // MARK: - Toggle individual

    @Test("Disabling a type persists")
    func disableType() {
        let store = makeStore()
        store.setEnabled(false, for: .hrvAnomaly)
        #expect(store.isEnabled(for: .hrvAnomaly) == false)
    }

    @Test("Re-enabling a type persists")
    func reEnableType() {
        let store = makeStore()
        store.setEnabled(false, for: .hrvAnomaly)
        store.setEnabled(true, for: .hrvAnomaly)
        #expect(store.isEnabled(for: .hrvAnomaly) == true)
    }

    @Test("Disabling one type does not affect others")
    func disableOneTypeIndependent() {
        let store = makeStore()
        store.setEnabled(false, for: .stepGoal)
        #expect(store.isEnabled(for: .hrvAnomaly) == true)
        #expect(store.isEnabled(for: .workoutPR) == true)
    }

    // MARK: - Master toggle

    @Test("setAllEnabled(false) disables all types")
    func disableAll() {
        let store = makeStore()
        store.setAllEnabled(false)
        for type in HealthInsight.InsightType.allCases {
            #expect(store.isEnabled(for: type) == false)
        }
        #expect(store.hasAnyEnabled == false)
    }

    @Test("setAllEnabled(true) re-enables all types")
    func enableAll() {
        let store = makeStore()
        store.setAllEnabled(false)
        store.setAllEnabled(true)
        for type in HealthInsight.InsightType.allCases {
            #expect(store.isEnabled(for: type) == true)
        }
    }
}
