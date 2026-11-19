import Foundation
import Testing
@testable import DUNE

@Suite("WhatsNewStore")
struct WhatsNewStoreTests {
    @Test("Shows a badge when no build has been opened yet")
    func showsBadgeWhenBuildIsNew() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        #expect(store.shouldShowBadge(version: "0.9.0", build: "42"))
        #expect(store.lastOpenedReleaseID() == nil)
    }

    @Test("Hides the badge after the same build is opened")
    func hidesBadgeForOpenedBuild() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        store.markOpened(version: "0.9.0", build: "42")

        #expect(store.shouldShowBadge(version: "0.9.0", build: "42") == false)
        #expect(store.lastOpenedReleaseID() == "0.9.0/42")
    }

    @Test("Shows the badge again when the build changes")
    func showsBadgeForUpdatedBuild() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        store.markOpened(version: "0.9.0", build: "42")

        #expect(store.shouldShowBadge(version: "0.9.0", build: "43"))
    }

    @Test("A legacy read marker or an earlier version with the same build leaves the new release unread")
    func reusedBuildNumber() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)
        let key = (Bundle.main.bundleIdentifier ?? "com.dailve") + ".whatsNew.lastOpenedBuild"
        defaults.set("1", forKey: key)
        #expect(store.shouldShowBadge(version: "0.9.0", build: "1"))

        store.markOpened(version: "0.8.0", build: "1")
        #expect(store.shouldShowBadge(version: "0.9.0", build: "1"))
        store.markOpened(version: "0.9.0", build: "1")
        #expect(!store.shouldShowBadge(version: "0.9.0", build: "1"))
    }

    @Test("Ignores empty build strings")
    func ignoresEmptyBuild() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        #expect(store.shouldShowBadge(version: "0.9.0", build: "") == false)

        store.markOpened(version: "0.9.0", build: "")

        #expect(store.lastOpenedReleaseID() == nil)
    }

    @Test("Inbox shows only the current catalog release and one unread item per build")
    func currentInboxRelease() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)
        let manager = WhatsNewManager(releases: [
            WhatsNewReleaseData(version: "1.0", introKey: "First", features: []),
            WhatsNewReleaseData(version: "2.0", introKey: "Second", features: [])
        ])

        #expect(WhatsNewInboxRelease.current(manager: manager, store: store, version: "3.0", build: "30") == nil)
        #expect(WhatsNewInboxRelease.current(manager: manager, store: store, version: "2.0", build: "") == nil)

        let unread = WhatsNewInboxRelease.current(manager: manager, store: store, version: "2.0", build: "20")
        #expect(unread?.release.version == "2.0")
        #expect(unread?.isUnread == true)

        store.markOpened(version: "2.0", build: "20")
        let read = WhatsNewInboxRelease.current(manager: manager, store: store, version: "2.0", build: "20")
        #expect(read?.isUnread == false)
        #expect(WhatsNewInboxRelease.current(manager: manager, store: store, version: "2.0", build: "21")?.isUnread == true)
    }

    private func makeDefaults(suffix: String) -> UserDefaults {
        let suiteName = "WhatsNewStoreTests.\(suffix)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
