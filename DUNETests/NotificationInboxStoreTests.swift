import Foundation
import Testing
@testable import DUNE

@Suite("NotificationInboxStore")
struct NotificationInboxStoreTests {

    @Test("append stores unread item and keeps latest-first ordering")
    func appendAndSortLatestFirst() {
        let store = makeStore()
        let older = HealthInsight(
            type: .workoutPR,
            title: "Older",
            body: "first",
            severity: .celebration,
            date: Date(timeIntervalSince1970: 10),
            route: .workoutDetail(workoutID: "workout-1")
        )
        let newer = HealthInsight(
            type: .workoutPR,
            title: "Newer",
            body: "second",
            severity: .celebration,
            date: Date(timeIntervalSince1970: 20),
            route: .workoutDetail(workoutID: "workout-2")
        )

        _ = store.append(insight: older)
        _ = store.append(insight: newer)

        let items = store.items()
        #expect(items.count == 2)
        #expect(items[0].title == "Newer")
        #expect(items[1].title == "Older")
        #expect(items.allSatisfy { !$0.isRead })
    }

    @Test("markRead marks only the target item")
    func markRead() {
        let store = makeStore()
        let first = store.append(insight: sampleInsight(workoutID: "a"))
        let second = store.append(insight: sampleInsight(workoutID: "b"))

        _ = store.markRead(id: first.id)

        let itemsByID = Dictionary(uniqueKeysWithValues: store.items().map { ($0.id, $0) })
        #expect(itemsByID[first.id]?.isRead == true)
        #expect(itemsByID[second.id]?.isRead == false)
        #expect(store.unreadCount() == 1)
    }

    @Test("markAllRead marks every unread item")
    func markAllRead() {
        let store = makeStore()
        _ = store.append(insight: sampleInsight(workoutID: "x"))
        _ = store.append(insight: sampleInsight(workoutID: "y"))

        store.markAllRead()

        let items = store.items()
        #expect(items.count == 2)
        #expect(items.allSatisfy { $0.isRead })
        #expect(store.unreadCount() == 0)
    }

    @Test("markUnread restores unread state and clears openedAt")
    func markUnread() {
        let store = makeStore()
        let item = store.append(insight: sampleInsight(workoutID: "x"))

        _ = store.markRead(id: item.id, openedAt: Date(timeIntervalSince1970: 100))
        let unread = store.markUnread(id: item.id)

        #expect(unread?.isRead == false)
        #expect(unread?.openedAt == nil)
        #expect(store.unreadCount() == 1)
    }

    @Test("delete removes only matching item")
    func deleteOne() {
        let store = makeStore()
        let first = store.append(insight: sampleInsight(workoutID: "a"))
        let second = store.append(insight: sampleInsight(workoutID: "b"))

        let removed = store.delete(id: first.id)
        let items = store.items()

        #expect(removed?.id == first.id)
        #expect(items.count == 1)
        #expect(items.first?.id == second.id)
    }

    @Test("deleteAll clears inbox")
    func deleteAll() {
        let store = makeStore()
        _ = store.append(insight: sampleInsight(workoutID: "x"))
        _ = store.append(insight: sampleInsight(workoutID: "y"))

        store.deleteAll()

        #expect(store.items().isEmpty)
        #expect(store.unreadCount() == 0)
    }

    private func makeStore() -> NotificationInboxStore {
        let suiteName = "NotificationInboxStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return NotificationInboxStore(defaults: defaults)
    }

    private func sampleInsight(workoutID: String) -> HealthInsight {
        HealthInsight(
            type: .workoutPR,
            title: "PR",
            body: "body",
            severity: .celebration,
            date: Date(),
            route: .workoutDetail(workoutID: workoutID)
        )
    }
}
