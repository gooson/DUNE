import Testing
import Foundation
@testable import DUNE

@Suite("TemplateNudgeDismissStore")
struct TemplateNudgeDismissStoreTests {
    private func makeStore() -> TemplateNudgeDismissStore {
        let defaults = UserDefaults(suiteName: "test-nudge-dismiss-\(UUID().uuidString)")!
        return TemplateNudgeDismissStore(defaults: defaults)
    }

    @Test("Undismissed recommendation returns false")
    func undismissed() {
        let store = makeStore()
        #expect(!store.isDismissed("rec-1"))
    }

    @Test("Dismissed recommendation returns true within 7 days")
    func dismissed() {
        let store = makeStore()
        store.dismiss("rec-1")
        #expect(store.isDismissed("rec-1"))
    }

    @Test("Different recommendation IDs are independent")
    func independent() {
        let store = makeStore()
        store.dismiss("rec-1")
        #expect(!store.isDismissed("rec-2"))
    }

    @Test("Dismiss persists across store instances with same defaults")
    func persistence() {
        let defaults = UserDefaults(suiteName: "test-nudge-persist-\(UUID().uuidString)")!
        let store1 = TemplateNudgeDismissStore(defaults: defaults)
        store1.dismiss("rec-1")

        let store2 = TemplateNudgeDismissStore(defaults: defaults)
        #expect(store2.isDismissed("rec-1"))
    }
}
