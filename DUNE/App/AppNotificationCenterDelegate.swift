import Foundation
import UserNotifications

struct NotificationResponsePayload: Sendable, Equatable {
    private enum UserInfoKeys {
        static let itemID = "notificationItemID"
        static let routeKind = "notificationRouteKind"
        static let workoutID = "notificationWorkoutID"
    }

    let itemID: String?
    let routeKind: String?
    let workoutID: String?

    init(
        itemID: String? = nil,
        routeKind: String? = nil,
        workoutID: String? = nil
    ) {
        self.itemID = itemID
        self.routeKind = routeKind
        self.workoutID = workoutID
    }

    init(userInfo: [AnyHashable: Any]) {
        self.init(
            itemID: userInfo[UserInfoKeys.itemID] as? String,
            routeKind: userInfo[UserInfoKeys.routeKind] as? String,
            workoutID: userInfo[UserInfoKeys.workoutID] as? String
        )
    }

    var userInfo: [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [:]
        if let itemID {
            userInfo[UserInfoKeys.itemID] = itemID
        }
        if let routeKind {
            userInfo[UserInfoKeys.routeKind] = routeKind
        }
        if let workoutID {
            userInfo[UserInfoKeys.workoutID] = workoutID
        }
        return userInfo
    }
}

/// Receives local notification interactions and forwards them into app routing.
final class AppNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let foregroundPresentationOptions: UNNotificationPresentationOptions = [
        .banner,
        .list,
        .sound,
        .badge
    ]

    private let responseHandler: @Sendable (NotificationResponsePayload) -> Void

    init(
        responseHandler: @escaping @Sendable (NotificationResponsePayload) -> Void = { payload in
            NotificationInboxManager.shared.handleNotificationResponse(userInfo: payload.userInfo)
        }
    ) {
        self.responseHandler = responseHandler
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Self.foregroundPresentationOptions
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await forwardNotificationResponse(
            NotificationResponsePayload(userInfo: response.notification.request.content.userInfo)
        )
    }

    func forwardNotificationResponse(_ payload: NotificationResponsePayload) async {
        let responseHandler = self.responseHandler
        await MainActor.run {
            responseHandler(payload)
        }
    }
}
