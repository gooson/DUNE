import Foundation
import Testing
@testable import DUNE

@Suite("WorkoutSettingsStore")
struct WorkoutSettingsStoreTests {

    // MARK: - Defaults (no saved value)

    @Test("Returns default rest seconds when no saved value")
    func defaultRestSeconds() {
        let store = makeStore()
        #expect(store.restSeconds == WorkoutSettingsStore.defaultRestSeconds)
    }

    @Test("Returns default set count when no saved value")
    func defaultSetCount() {
        let store = makeStore()
        #expect(store.setCount == WorkoutSettingsStore.defaultSetCount)
    }

    @Test("Returns default body weight when no saved value")
    func defaultBodyWeight() {
        let store = makeStore()
        #expect(store.bodyWeightKg == WorkoutSettingsStore.defaultBodyWeightKg)
    }

    // MARK: - Round-trip persistence

    @Test("Rest seconds persists and reads back")
    func restSecondsRoundTrip() {
        let store = makeStore()
        store.restSeconds = 120
        #expect(store.restSeconds == 120)
    }

    @Test("Set count persists and reads back")
    func setCountRoundTrip() {
        let store = makeStore()
        store.setCount = 8
        #expect(store.setCount == 8)
    }

    @Test("Body weight persists and reads back")
    func bodyWeightRoundTrip() {
        let store = makeStore()
        store.bodyWeightKg = 85.5
        #expect(store.bodyWeightKg == 85.5)
    }

    // MARK: - Clamping (upper bound)

    @Test("Rest seconds clamps to upper bound on write")
    func restSecondsClampsUpper() {
        let store = makeStore()
        store.restSeconds = 9999
        #expect(store.restSeconds == WorkoutSettingsStore.restSecondsRange.upperBound)
    }

    @Test("Set count clamps to upper bound on write")
    func setCountClampsUpper() {
        let store = makeStore()
        store.setCount = 100
        #expect(store.setCount == WorkoutSettingsStore.setCountRange.upperBound)
    }

    @Test("Body weight clamps to upper bound on write")
    func bodyWeightClampsUpper() {
        let store = makeStore()
        store.bodyWeightKg = 999
        #expect(store.bodyWeightKg == WorkoutSettingsStore.bodyWeightRange.upperBound)
    }

    // MARK: - Clamping (lower bound)

    @Test("Rest seconds clamps to lower bound on write")
    func restSecondsClampsLower() {
        let store = makeStore()
        store.restSeconds = 1
        #expect(store.restSeconds == WorkoutSettingsStore.restSecondsRange.lowerBound)
    }

    @Test("Set count clamps to lower bound on write")
    func setCountClampsLower() {
        let store = makeStore()
        store.setCount = 0
        // 0 triggers the `guard value > 0` path, returning default
        #expect(store.setCount == WorkoutSettingsStore.setCountRange.lowerBound)
    }

    @Test("Body weight clamps to lower bound on write")
    func bodyWeightClampsLower() {
        let store = makeStore()
        store.bodyWeightKg = 5
        #expect(store.bodyWeightKg == WorkoutSettingsStore.bodyWeightRange.lowerBound)
    }

    // MARK: - Boundary values

    @Test("Rest seconds accepts exact lower bound")
    func restSecondsExactLower() {
        let store = makeStore()
        store.restSeconds = 15
        #expect(store.restSeconds == 15)
    }

    @Test("Rest seconds accepts exact upper bound")
    func restSecondsExactUpper() {
        let store = makeStore()
        store.restSeconds = 600
        #expect(store.restSeconds == 600)
    }

    @Test("Set count accepts exact lower bound")
    func setCountExactLower() {
        let store = makeStore()
        store.setCount = 1
        #expect(store.setCount == 1)
    }

    @Test("Set count accepts exact upper bound")
    func setCountExactUpper() {
        let store = makeStore()
        store.setCount = 20
        #expect(store.setCount == 20)
    }

    // MARK: - Reset

    @Test("resetToDefaults clears all saved values")
    func resetToDefaults() {
        let store = makeStore()
        store.restSeconds = 200
        store.setCount = 10
        store.bodyWeightKg = 100

        store.resetToDefaults()

        #expect(store.restSeconds == WorkoutSettingsStore.defaultRestSeconds)
        #expect(store.setCount == WorkoutSettingsStore.defaultSetCount)
        #expect(store.bodyWeightKg == WorkoutSettingsStore.defaultBodyWeightKg)
    }

    // MARK: - Isolation

    @Test("Two stores with different UserDefaults are isolated")
    func storeIsolation() {
        let storeA = makeStore()
        let storeB = makeStore()

        storeA.restSeconds = 300
        #expect(storeB.restSeconds == WorkoutSettingsStore.defaultRestSeconds)
    }

    // MARK: - Helper

    private func makeStore() -> WorkoutSettingsStore {
        let suiteName = "WorkoutSettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return WorkoutSettingsStore(defaults: defaults)
    }
}
