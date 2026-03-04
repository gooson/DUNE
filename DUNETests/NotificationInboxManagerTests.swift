import Foundation
import Testing
@testable import DUNE

@Suite("NotificationInboxManager")
struct NotificationInboxManagerTests {

    @Test("markAllRead synchronizes badge count to zero")
    func markAllReadSynchronizesBadgeCount() async {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )

        _ = manager.recordSentInsight(sampleInsight(workoutID: "workout-1"))
        _ = manager.recordSentInsight(sampleInsight(workoutID: "workout-2"))
        await waitForCondition { recorder.snapshot().contains(2) }

        manager.markAllRead()
        await waitForCondition { recorder.lastValue() == 0 }

        #expect(store.unreadCount() == 0)
        #expect(recorder.lastValue() == 0)
    }

    @Test("deleteAll synchronizes badge count to zero")
    func deleteAllSynchronizesBadgeCount() async {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )

        _ = manager.recordSentInsight(sampleInsight(workoutID: "workout-1"))
        _ = manager.recordSentInsight(sampleInsight(workoutID: "workout-2"))
        await waitForCondition { recorder.snapshot().contains(2) }

        manager.deleteAll()
        await waitForCondition { recorder.lastValue() == 0 }

        #expect(store.items().isEmpty)
        #expect(recorder.lastValue() == 0)
    }

    private func makeStore() -> NotificationInboxStore {
        let suiteName = "NotificationInboxManagerTests.\(UUID().uuidString)"
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

    private func waitForCondition(
        maxAttempts: Int = 120,
        intervalNanoseconds: UInt64 = 5_000_000,
        _ condition: @escaping () -> Bool
    ) async {
        for _ in 0..<maxAttempts {
            if condition() {
                return
            }
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
        }
    }
}

private final class BadgeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Int] = []

    func record(_ value: Int) {
        lock.lock()
        values.append(value)
        lock.unlock()
    }

    func lastValue() -> Int? {
        lock.lock()
        defer { lock.unlock() }
        return values.last
    }

    func snapshot() -> [Int] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}
