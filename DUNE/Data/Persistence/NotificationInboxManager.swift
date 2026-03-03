import Foundation

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
    private let queue = DispatchQueue(label: "com.dune.notification-inbox-manager")
    private var pendingNavigationRequest: NotificationNavigationRequest?

    init(store: NotificationInboxStore = .shared) {
        self.store = store
    }

    func items() -> [NotificationInboxItem] {
        store.items()
    }

    func unreadCount() -> Int {
        store.unreadCount()
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

    func markAllRead() {
        store.markAllRead()
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
        Task { @MainActor in
            NotificationCenter.default.post(name: Self.inboxDidChangeNotification, object: nil)
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
