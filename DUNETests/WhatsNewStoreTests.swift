import Foundation
import Testing
@testable import DUNE

@Suite("WhatsNewStore")
struct WhatsNewStoreTests {
    @Test("Presents when no version has been marked yet")
    func presentsWhenVersionIsNew() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        #expect(store.shouldPresent(version: "0.2.0"))
        #expect(store.lastPresentedVersion() == nil)
    }

    @Test("Does not present again for the same version")
    func skipsAlreadyPresentedVersion() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        store.markPresented(version: "0.2.0")

        #expect(store.shouldPresent(version: "0.2.0") == false)
        #expect(store.lastPresentedVersion() == "0.2.0")
    }

    @Test("Presents again when the app version changes")
    func presentsUpdatedVersion() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        store.markPresented(version: "0.2.0")

        #expect(store.shouldPresent(version: "0.3.0"))
    }

    @Test("Ignores empty version strings")
    func ignoresEmptyVersion() {
        let defaults = makeDefaults(suffix: #function)
        let store = WhatsNewStore(defaults: defaults)

        #expect(store.shouldPresent(version: "") == false)

        store.markPresented(version: "")

        #expect(store.lastPresentedVersion() == nil)
    }

    private func makeDefaults(suffix: String) -> UserDefaults {
        let suiteName = "WhatsNewStoreTests.\(suffix)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
