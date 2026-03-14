import Foundation
import UserNotifications

/// Receives local notification interactions and forwards them into app routing.
///
/// Both delegate methods use the completion-handler signature (not the async
/// overload) so that the completion handler is always called on the main thread.
/// The async overload resumes on an arbitrary executor after `await`, which
/// causes UIKit's internal `_performBlockAfterCATransactionCommitSynchronizes:`
/// to assert when the completion fires off-main.
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler(Self.foregroundPresentationOptions)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let payload = NotificationResponsePayload(
            userInfo: content.userInfo,
            title: content.title,
            body: content.body,
            date: response.notification.date
        )
        AppLogger.notification.info("[NotificationDelegate] didReceive: itemID=\(payload.itemID ?? "nil"), routeKind=\(payload.routeKind ?? "nil"), insightType=\(payload.insightType ?? "nil")")
        // UNUserNotificationCenter calls delegate methods on the main thread,
        // so responseHandler and completionHandler can be invoked synchronously.
        responseHandler(payload)
        completionHandler()
    }
}
