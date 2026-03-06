import Testing
@testable import DUNE

@Suite("WhatsNewManager")
struct WhatsNewManagerTests {
    @Test("Current release includes theme, weather, sleep debt, muscle map, and widget announcements")
    func currentReleaseIncludesThemeWeatherSleepDebtMuscleMapAndWidgets() {
        let manager = WhatsNewManager.shared

        let release = manager.currentRelease(for: "0.2.0")

        #expect(release != nil)
        #expect(release?.features.contains(.widgets) == true)
        #expect(release?.features.contains(.themes) == true)
        #expect(release?.features.contains(.weather) == true)
        #expect(release?.features.contains(.sleepDebt) == true)
        #expect(release?.features.contains(.muscleMap) == true)
    }
}
