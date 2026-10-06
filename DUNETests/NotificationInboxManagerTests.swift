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

    @Test("matching consume clears active pending request exactly once")
    func consumePendingNavigationRequestIfMatchingClearsPendingRequest() {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )
        let request = NotificationNavigationRequest(
            itemID: "item-1",
            route: .activityPersonalRecords
        )

        manager.requestNavigation(itemID: request.itemID, route: request.route)

        #expect(manager.consumePendingNavigationRequest(ifMatching: request))
        #expect(manager.consumePendingNavigationRequest() == nil)
    }

    @Test("matching consume ignores request already taken by startup consumer")
    func consumePendingNavigationRequestIfMatchingIgnoresConsumedRequest() {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )
        let request = NotificationNavigationRequest(
            itemID: "item-2",
            route: .notificationHub
        )

        manager.requestNavigation(itemID: request.itemID, route: request.route)

        let pending = manager.consumePendingNavigationRequest()
        #expect(pending == request)
        #expect(!manager.consumePendingNavigationRequest(ifMatching: request))
    }

    @Test("legacy level-up workout route is redirected to personal records")
    func handleNotificationResponseLegacyLevelUpRedirect() async {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )

        let item = manager.recordSentInsight(HealthInsight(
            type: .workoutPR,
            title: "레벨 업!",
            body: "축하합니다",
            severity: .celebration,
            date: Date(),
            route: .workoutDetail(workoutID: "workout-legacy")
        ))

        let userInfo = manager.notificationUserInfo(for: item)
        manager.handleNotificationResponse(userInfo: userInfo)

        let pending = manager.consumePendingNavigationRequest()
        #expect(pending != nil)
        #expect(pending?.route.destination == .activityPersonalRecords)
    }

    @Test("handleNotificationResponse creates item via fallback when no itemID but insightType present")
    func handleNotificationResponseFallbackWithInsightType() async {
        let store = makeStore()
        let recorder = BadgeRecorder()
        let manager = NotificationInboxManager(
            store: store,
            badgeUpdater: { recorder.record($0) }
        )

        // Simulate a bedtime reminder notification (no itemID, but has insightType + routeKind)
        let userInfo: [AnyHashable: Any] = [
            "notificationRouteKind": "sleepDetail",
            "notificationInsightType": "sleepComplete"
        ]

        manager.handleNotificationResponse(
            userInfo: userInfo,
            fallbackTitle: "Time for Bed",
            fallbackBody: "It's your scheduled bedtime",
            fallbackDate: Date()
        )

        // Should have created an inbox item and routed to sleepDetail
        let items = manager.items()
        #expect(!items.isEmpty)
        let createdItem = items.first
        #expect(createdItem?.insightType == .sleepComplete)
        #expect(createdItem?.isRead == true)
        #expect(createdItem?.route == .sleepDetail)
        #expect(manager.consumePendingNavigationRequest()?.route == .sleepDetail)
    }

    @Test("A route-less legacy notification creates an item and opens its hub detail")
    func routeLessFallbackOpensHubDetail() throws {
        let manager = NotificationInboxManager(store: makeStore(), badgeUpdater: { _ in })

        manager.handleNotificationResponse(
            userInfo: ["notificationInsightType": HealthInsight.InsightType.sleepDebt.rawValue],
            fallbackTitle: "Sleep Debt Alert",
            fallbackBody: "Rest tonight"
        )

        let item = try #require(manager.items().first)
        let request = try #require(manager.consumePendingNavigationRequest())
        #expect(item.isRead)
        #expect(request.itemID == item.id)
        #expect(request.route == .notificationHub)
    }

    @Test("Posture reminder without an item ID opens posture assessment")
    func postureReminderFallbackRoute() {
        let manager = NotificationInboxManager(store: makeStore(), badgeUpdater: { _ in })
        manager.handleNotificationResponse(
            userInfo: ["notificationInsightType": "postureReminder"],
            fallbackTitle: "Time for a posture check-up",
            fallbackBody: "Check your posture"
        )

        #expect(manager.items().first?.isRead == true)
        #expect(manager.consumePendingNavigationRequest()?.route == .postureAssessment)
    }

    @Test("A saved posture reminder without a route still opens posture assessment")
    func legacyPostureReminderRoute() throws {
        let suiteName = "NotificationInboxManagerLegacyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let item = NotificationInboxItem(
            id: UUID().uuidString,
            insightType: .postureReminder,
            title: "Posture reminder",
            body: "Check your posture",
            createdAt: Date(),
            isRead: false,
            openedAt: nil,
            route: nil,
            source: .localNotification
        )
        let key = "\(Bundle.main.bundleIdentifier ?? "com.dailve").notificationInbox.items"
        defaults.set(try JSONEncoder().encode([item]), forKey: key)
        let manager = NotificationInboxManager(
            store: NotificationInboxStore(defaults: defaults),
            badgeUpdater: { _ in }
        )

        _ = manager.open(itemID: item.id)

        #expect(manager.consumePendingNavigationRequest()?.route == .postureAssessment)
    }

    @Test("Daily digest without an item ID opens the notification hub")
    func dailyDigestFallbackRoute() {
        let manager = NotificationInboxManager(store: makeStore(), badgeUpdater: { _ in })
        manager.handleNotificationResponse(
            userInfo: ["notificationInsightType": "dailyDigest"],
            fallbackTitle: "Today's Summary",
            fallbackBody: "Review your daily health summary"
        )

        #expect(manager.consumePendingNavigationRequest()?.route == .notificationHub)
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
