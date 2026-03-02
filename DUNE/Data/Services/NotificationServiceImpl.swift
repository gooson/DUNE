import Foundation
import UserNotifications

/// Wraps UNUserNotificationCenter for local notification delivery.
final class NotificationServiceImpl: NotificationService, @unchecked Sendable {

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            AppLogger.notification.error("[NotificationService] Authorization request failed: \(error.localizedDescription)")
            return false
        }
    }

    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func send(_ insight: HealthInsight) async {
        guard await isAuthorized() else { return }

        let content = UNMutableNotificationContent()
        content.title = insight.title
        content.body = insight.body
        content.sound = insight.severity == .celebration ? .defaultCritical : .default
        content.categoryIdentifier = insight.type.rawValue

        let request = UNNotificationRequest(
            identifier: "\(insight.type.rawValue)-\(insight.date.timeIntervalSince1970)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        do {
            try await center.add(request)
            AppLogger.notification.info("[NotificationService] Sent: \(insight.type.rawValue) — \(insight.title)")
        } catch {
            AppLogger.notification.error("[NotificationService] Send failed: \(error.localizedDescription)")
        }
    }
}
