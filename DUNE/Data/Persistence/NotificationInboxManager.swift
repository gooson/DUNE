import Foundation
import UserNotifications

struct NotificationNavigationRequest: Sendable, Equatable {
    let itemID: String
    let route: NotificationRoute
}

/// Shared facade for notification history persistence + app navigation requests.
final class NotificationInboxManager: @unchecked Sendable {
    static let shared = NotificationInboxManager()

    static let inboxDidChangeNotification = Notification.Name("NotificationInboxManager.inboxDidChange")
    static let routeRequestedNotification = Notification.Name("NotificationInboxManager.routeRequested")

    private enum UserInfoKeys {
        static let itemID = "notificationItemID"
        static let routeKind = "notificationRouteKind"
        static let workoutID = "notificationWorkoutID"
    }

    private let store: NotificationInboxStore
    private let badgeUpdater: @Sendable (Int) -> Void
    private let queue = DispatchQueue(label: "com.dune.notification-inbox-manager")
    private var pendingNavigationRequest: NotificationNavigationRequest?

    init(
        store: NotificationInboxStore = .shared,
        badgeUpdater: @escaping @Sendable (Int) -> Void = { count in
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error {
                    AppLogger.notification.error("[NotificationInboxManager] Failed to sync badge count: \(error.localizedDescription)")
                }
            }
        }
    ) {
        self.store = store
        self.badgeUpdater = badgeUpdater
    }

    func items() -> [NotificationInboxItem] {
        store.items()
    }

    func unreadCount() -> Int {
        store.unreadCount()
    }

    /// Synchronizes the system app-icon badge with the current unread count
    /// and removes delivered notifications when the inbox is fully read.
    func syncBadge() {
        let unreadCount = store.unreadCount()
        badgeUpdater(unreadCount)
        if unreadCount == 0 {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
    }

    @discardableResult
    func recordSentInsight(_ insight: HealthInsight) -> NotificationInboxItem {
        let item = store.append(insight: insight)
        postInboxDidChange()
        return item
    }

    func markRead(id: String) {
        _ = store.markRead(id: id)
        postInboxDidChange()
    }

    func markUnread(id: String) {
        _ = store.markUnread(id: id)
        postInboxDidChange()
    }

    func markAllRead() {
        store.markAllRead()
        postInboxDidChange()
    }

    @discardableResult
    func delete(id: String) -> NotificationInboxItem? {
        let removed = store.delete(id: id)
        if removed != nil {
            postInboxDidChange()
        }
        return removed
    }

    func deleteAll() {
        store.deleteAll()
        postInboxDidChange()
    }

    @discardableResult
    func open(itemID: String) -> NotificationInboxItem? {
        guard let existing = store.item(withID: itemID) else { return nil }
        _ = store.markRead(id: itemID)
        postInboxDidChange()

        guard let route = existing.route else { return existing }
        emitNavigationRequest(.init(itemID: itemID, route: route))
        return existing
    }

    func handleNotificationResponse(userInfo: [AnyHashable: Any]) {
        let itemID = userInfo[UserInfoKeys.itemID] as? String
        if let itemID {
            let openedItem = open(itemID: itemID)
            if openedItem?.route != nil {
                return
            }
            if let route = parseRoute(userInfo: userInfo) {
                emitNavigationRequest(.init(itemID: itemID, route: route))
                return
            }
            // Non-routed notification (sleep, HRV, etc.) — navigate to hub
            emitNavigationRequest(.init(itemID: itemID, route: .notificationHub))
            return
        }

        guard let route = parseRoute(userInfo: userInfo) else { return }
        let request = NotificationNavigationRequest(
            itemID: UUID().uuidString,
            route: route
        )
        emitNavigationRequest(request)
    }

    func notificationUserInfo(for item: NotificationInboxItem) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [UserInfoKeys.itemID: item.id]
        guard let route = item.route else { return userInfo }

        switch route.destination {
        case .workoutDetail:
            userInfo[UserInfoKeys.routeKind] = route.destination.rawValue
            if let workoutID = route.workoutID, !workoutID.isEmpty {
                userInfo[UserInfoKeys.workoutID] = workoutID
            }
        case .notificationHub:
            break // Hub route is resolved at navigation time; no payload needed in userInfo
        }
        return userInfo
    }

    func consumePendingNavigationRequest() -> NotificationNavigationRequest? {
        queue.sync {
            defer { pendingNavigationRequest = nil }
            return pendingNavigationRequest
        }
    }

    func clearPendingNavigationRequest(ifMatching request: NotificationNavigationRequest) {
        queue.sync {
            if pendingNavigationRequest == request {
                pendingNavigationRequest = nil
            }
        }
    }

    static func navigationRequest(from notification: Notification) -> NotificationNavigationRequest? {
        notification.object as? NotificationNavigationRequest
    }

    private func emitNavigationRequest(_ request: NotificationNavigationRequest) {
        queue.sync {
            pendingNavigationRequest = request
        }
        Task { @MainActor in
            NotificationCenter.default.post(name: Self.routeRequestedNotification, object: request)
        }
    }

    private func postInboxDidChange() {
        let unreadCount = store.unreadCount()
        Task { @MainActor in
            NotificationCenter.default.post(name: Self.inboxDidChangeNotification, object: nil)
            badgeUpdater(unreadCount)
        }
    }

    private func parseRoute(userInfo: [AnyHashable: Any]) -> NotificationRoute? {
        guard let rawKind = userInfo[UserInfoKeys.routeKind] as? String,
              rawKind == NotificationRoute.Destination.workoutDetail.rawValue,
              let workoutID = userInfo[UserInfoKeys.workoutID] as? String,
              !workoutID.isEmpty else {
            return nil
        }
        return .workoutDetail(workoutID: workoutID)
    }
}
