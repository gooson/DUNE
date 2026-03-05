import Foundation
import UserNotifications

/// Receives local notification interactions and forwards them into app routing.
final class AppNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let inboxManager: NotificationInboxManager

    init(inboxManager: NotificationInboxManager = .shared) {
        self.inboxManager = inboxManager
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        inboxManager.handleNotificationResponse(
            userInfo: response.notification.request.content.userInfo
        )
    }
}
