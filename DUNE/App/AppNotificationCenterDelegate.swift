import Foundation
import UserNotifications

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
            NotificationInboxManager.shared.handleNotificationResponse(
                userInfo: payload.userInfo,
                fallbackTitle: payload.title,
                fallbackBody: payload.body,
                fallbackDate: payload.date ?? Date()
            )
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
        let content = response.notification.request.content
        let payload = NotificationResponsePayload(
            userInfo: content.userInfo,
            title: content.title,
            body: content.body,
            date: response.notification.date
        )
        AppLogger.notification.info("[NotificationDelegate] didReceive: itemID=\(payload.itemID ?? "nil"), routeKind=\(payload.routeKind ?? "nil"), insightType=\(payload.insightType ?? "nil")")
        await forwardNotificationResponse(payload)
    }

    func forwardNotificationResponse(_ payload: NotificationResponsePayload) async {
        let responseHandler = self.responseHandler
        await MainActor.run {
            responseHandler(payload)
        }
    }
}
