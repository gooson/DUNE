import Foundation
import Testing
@testable import DUNE

@Suite("TodayPinnedMetricsStore")
struct TodayPinnedMetricsStoreTests {
    @Test("Load returns fallback categories when no saved value")
    func loadFallback() {
        let defaults = makeDefaults()
        let store = TodayPinnedMetricsStore(defaults: defaults)

        let loaded = store.load()

        #expect(loaded == [.hrv, .rhr, .sleep])
    }

    @Test("Save normalizes duplicates and enforces top 3")
    func saveNormalization() {
        let defaults = makeDefaults()
        let store = TodayPinnedMetricsStore(defaults: defaults)

        store.save([.steps, .steps, .hrv, .rhr, .sleep])
        let loaded = store.load()

        #expect(loaded == [.steps, .hrv, .rhr])
    }

    @Test("Load ignores invalid raw values")
    func loadIgnoresInvalidRawValues() {
        let defaults = makeDefaults()
        let store = TodayPinnedMetricsStore(defaults: defaults)
        let key = "\(Bundle.main.bundleIdentifier ?? "com.dailve").today.pinnedMetricCategories"

        defaults.set(["invalid", "hrv", "sleep", "rhr", "exercise"], forKey: key)
        let loaded = store.load()

        #expect(loaded == [.hrv, .sleep, .rhr])
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "TodayPinnedMetricsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
