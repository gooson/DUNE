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
        static let insightType = "notificationInsightType"
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

        guard let route = preferredRoute(for: existing) else { return existing }
        emitNavigationRequest(.init(itemID: itemID, route: route))
        return existing
    }

    /// Marks the item as read and returns it without emitting a navigation request.
    /// Use this when the caller handles navigation locally (e.g., NotificationHubView push).
    @discardableResult
    func openLocally(itemID: String) -> NotificationInboxItem? {
        guard let existing = store.item(withID: itemID) else { return nil }
        _ = store.markRead(id: itemID)
        postInboxDidChange()
        return existing
    }

    func handleNotificationResponse(
        userInfo: [AnyHashable: Any],
        fallbackTitle: String? = nil,
        fallbackBody: String? = nil,
        fallbackDate: Date = Date()
    ) {
        let itemID = userInfo[UserInfoKeys.itemID] as? String
        let routeKind = userInfo[UserInfoKeys.routeKind] as? String
        let insightTypeRaw = userInfo[UserInfoKeys.insightType] as? String
        AppLogger.notification.info("[InboxManager] handleNotificationResponse: itemID=\(itemID ?? "nil"), routeKind=\(routeKind ?? "nil"), insightType=\(insightTypeRaw ?? "nil"), hasFallbackTitle=\(fallbackTitle != nil)")

        if let itemID {
            let openedItem = open(itemID: itemID)
            if let openedItem, preferredRoute(for: openedItem) != nil {
                AppLogger.notification.info("[InboxManager] Routed via preferredRoute for itemID=\(itemID)")
                return
            }
            if openedItem?.insightType == .workoutPR {
                AppLogger.notification.info("[InboxManager] Routing workoutPR to activityPersonalRecords")
                emitNavigationRequest(.init(itemID: itemID, route: .activityPersonalRecords))
                return
            }
            if let route = parseRoute(userInfo: userInfo) {
                AppLogger.notification.info("[InboxManager] Routing via parseRoute: \(route.destination.rawValue)")
                emitNavigationRequest(.init(itemID: itemID, route: route))
                return
            }
            // Non-routed notification (sleep, HRV, etc.) — navigate to hub
            AppLogger.notification.info("[InboxManager] No route found, falling back to notificationHub")
            emitNavigationRequest(.init(itemID: itemID, route: .notificationHub))
            return
        }

        if let fallbackTitle,
           let fallbackBody,
           let insightTypeRaw,
           let insightType = HealthInsight.InsightType(rawValue: insightTypeRaw) {
            let route = parseRoute(userInfo: userInfo)
            AppLogger.notification.info("[InboxManager] Fallback path: creating insight type=\(insightType.rawValue), route=\(route?.destination.rawValue ?? "nil")")
            let insight = HealthInsight(
                type: insightType,
                title: fallbackTitle,
                body: fallbackBody,
                severity: .informational,
                date: fallbackDate,
                route: route
            )
            let item = recordSentInsight(insight)
            _ = open(itemID: item.id)
            return
        }

        guard let route = parseRoute(userInfo: userInfo) else {
            AppLogger.notification.warning("[InboxManager] No itemID, no fallback, no route — notification dropped")
            return
        }
        AppLogger.notification.info("[InboxManager] Route-only path: \(route.destination.rawValue)")
        let request = NotificationNavigationRequest(
            itemID: UUID().uuidString,
            route: route
        )
        emitNavigationRequest(request)
    }

    func notificationUserInfo(for item: NotificationInboxItem) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [
            UserInfoKeys.itemID: item.id,
            UserInfoKeys.insightType: item.insightType.rawValue
        ]
        guard let route = item.route else { return userInfo }

        switch route.destination {
        case .workoutDetail:
            userInfo[UserInfoKeys.routeKind] = route.destination.rawValue
            if let workoutID = route.workoutID, !workoutID.isEmpty {
                userInfo[UserInfoKeys.workoutID] = workoutID
            }
        case .activityPersonalRecords:
            userInfo[UserInfoKeys.routeKind] = route.destination.rawValue
        case .notificationHub:
            break // Hub route is resolved at navigation time; no payload needed in userInfo
        case .sleepDetail:
            userInfo[UserInfoKeys.routeKind] = route.destination.rawValue
        }
        return userInfo
    }

    func requestNavigation(itemID: String, route: NotificationRoute) {
        emitNavigationRequest(.init(itemID: itemID, route: route))
    }

    func consumePendingNavigationRequest() -> NotificationNavigationRequest? {
        queue.sync {
            defer { pendingNavigationRequest = nil }
            return pendingNavigationRequest
        }
    }

    @discardableResult
    func consumePendingNavigationRequest(ifMatching request: NotificationNavigationRequest) -> Bool {
        queue.sync {
            guard pendingNavigationRequest == request else { return false }
            pendingNavigationRequest = nil
            return true
        }
    }

    static func navigationRequest(from notification: Notification) -> NotificationNavigationRequest? {
        notification.object as? NotificationNavigationRequest
    }

    private func emitNavigationRequest(_ request: NotificationNavigationRequest) {
        AppLogger.notification.info("[InboxManager] emitNavigationRequest: itemID=\(request.itemID), route=\(request.route.destination.rawValue)")
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
              let destination = NotificationRoute.Destination(rawValue: rawKind) else {
            return nil
        }

        switch destination {
        case .workoutDetail:
            guard let workoutID = userInfo[UserInfoKeys.workoutID] as? String,
                  !workoutID.isEmpty else {
                return nil
            }
            return .workoutDetail(workoutID: workoutID)
        case .activityPersonalRecords:
            return .activityPersonalRecords
        case .notificationHub:
            return .notificationHub
        case .sleepDetail:
            return .sleepDetail
        }
    }

    private func preferredRoute(for item: NotificationInboxItem) -> NotificationRoute? {
        guard let route = item.route else { return nil }

        guard item.insightType == .workoutPR else {
            return route
        }

        if route.destination == .workoutDetail, isLikelyLevelUpNotification(item.title) {
            return .activityPersonalRecords
        }

        return route
    }

    private func isLikelyLevelUpNotification(_ title: String) -> Bool {
        let normalized = normalizeRouteToken(title)
        return normalized.contains("levelup") || normalized.contains("레벨업")
    }

    private func normalizeRouteToken(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"[[:space:][:punct:]]+"#, with: "", options: .regularExpression)
    }
}
