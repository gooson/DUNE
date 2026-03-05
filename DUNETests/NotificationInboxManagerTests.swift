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

    @Test("syncBadge synchronizes badge count without state mutation")
    func syncBadgeSynchronizesBadgeCount() {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )

        _ = manager.recordSentInsight(sampleInsight(workoutID: "workout-1"))
        _ = manager.recordSentInsight(sampleInsight(workoutID: "workout-2"))
        recorder.reset()

        // syncBadge should report current unread count synchronously
        manager.syncBadge()
        #expect(recorder.lastValue() == 2)

        manager.markAllRead()
        recorder.reset()

        manager.syncBadge()
        #expect(recorder.lastValue() == 0)
    }

    @Test("handleNotificationResponse emits notificationHub for non-routed notification")
    func handleNotificationResponseNonRouted() async {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )

        // Record a sleep insight (no route)
        let sleepInsight = HealthInsight(
            type: .sleepComplete,
            title: "Sleep Recorded",
            body: "Last night: 7h 30m of sleep",
            severity: .informational
        )
        let item = manager.recordSentInsight(sleepInsight)

        // Build userInfo as the notification system would
        let userInfo = manager.notificationUserInfo(for: item)

        // Simulate notification tap
        manager.handleNotificationResponse(userInfo: userInfo)

        // Should have a pending navigation request to notificationHub
        let pending = manager.consumePendingNavigationRequest()
        #expect(pending != nil)
        #expect(pending?.route.destination == .notificationHub)
        #expect(pending?.itemID == item.id)
    }

    @Test("handleNotificationResponse emits activityPersonalRecords for non-routed workoutPR notification")
    func handleNotificationResponseNonRoutedWorkoutPR() async {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )

        let workoutInsight = HealthInsight(
            type: .workoutPR,
            title: "Level Up!",
            body: "You reached level 4",
            severity: .celebration
        )
        let item = manager.recordSentInsight(workoutInsight)
        let userInfo = manager.notificationUserInfo(for: item)

        manager.handleNotificationResponse(userInfo: userInfo)

        let pending = manager.consumePendingNavigationRequest()
        #expect(pending != nil)
        #expect(pending?.route.destination == .activityPersonalRecords)
        #expect(pending?.itemID == item.id)
    }

    @Test("handleNotificationResponse routes workout notifications to workoutDetail")
    func handleNotificationResponseRouted() async {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )

        // Record a workout PR insight (with route)
        let item = manager.recordSentInsight(sampleInsight(workoutID: "workout-123"))

        // Build userInfo
        let userInfo = manager.notificationUserInfo(for: item)

        // Simulate notification tap
        manager.handleNotificationResponse(userInfo: userInfo)

        // Should have a pending navigation request to workoutDetail
        let pending = manager.consumePendingNavigationRequest()
        #expect(pending != nil)
        #expect(pending?.route.destination == .workoutDetail)
        #expect(pending?.route.workoutID == "workout-123")
    }

    @Test("handleNotificationResponse marks non-routed notification as read")
    func handleNotificationResponseMarksRead() async {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )

        let sleepInsight = HealthInsight(
            type: .sleepComplete,
            title: "Sleep Recorded",
            body: "Last night: 7h 30m of sleep",
            severity: .informational
        )
        let item = manager.recordSentInsight(sleepInsight)
        #expect(!item.isRead)

        let userInfo = manager.notificationUserInfo(for: item)
        manager.handleNotificationResponse(userInfo: userInfo)

        // Item should be marked as read
        let items = manager.items()
        let updated = items.first { $0.id == item.id }
        #expect(updated?.isRead == true)
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

    func reset() {
        lock.lock()
        values.removeAll()
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
