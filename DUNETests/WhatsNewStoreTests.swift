import Foundation
import Testing
@testable import DUNE

@Suite("WhatsNewStore")
struct WhatsNewStoreTests {
    @Test("Shows a badge when no build has been opened yet")
    func showsBadgeWhenBuildIsNew() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        #expect(store.shouldShowBadge(build: "42"))
        #expect(store.lastOpenedBuild() == nil)
    }

    @Test("Hides the badge after the same build is opened")
    func hidesBadgeForOpenedBuild() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        store.markOpened(build: "42")

        #expect(store.shouldShowBadge(build: "42") == false)
        #expect(store.lastOpenedBuild() == "42")
    }

    @Test("Shows the badge again when the build changes")
    func showsBadgeForUpdatedBuild() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        store.markOpened(build: "42")

        #expect(store.shouldShowBadge(build: "43"))
    }

    @Test("Ignores empty build strings")
    func ignoresEmptyBuild() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        #expect(store.shouldShowBadge(build: "") == false)

        store.markOpened(build: "")

        #expect(store.lastOpenedBuild() == nil)
    }

    private func makeDefaults(suffix: String) -> UserDefaults {
        let suiteName = "WhatsNewStoreTests.\(suffix)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
