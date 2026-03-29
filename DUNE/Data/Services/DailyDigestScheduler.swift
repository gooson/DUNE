import Foundation
import UserNotifications

/// Schedules a daily evening digest notification at 21:00.
@MainActor
final class DailyDigestScheduler {
    static let shared = DailyDigestScheduler()
    static let settingsKey = "isDailyDigestEnabled"

    private enum Constants {
        static let notificationIdentifier = "com.raftel.dune.daily-digest"
        static let defaultHour = 21
        static let defaultMinute = 0
    }

    private let notificationScheduler: BedtimeReminderNotificationScheduling
    private let userDefaults: UserDefaults
    private let digestUseCase = GenerateDailyDigestUseCase()

    init(
        notificationScheduler: BedtimeReminderNotificationScheduling = UserNotificationCenterBedtimeReminderScheduler(),
        userDefaults: UserDefaults = .standard
    ) {
        self.notificationScheduler = notificationScheduler
        self.userDefaults = userDefaults
    }

    func refreshSchedule(force: Bool = false) async {
        let isEnabled = userDefaults.object(forKey: Self.settingsKey) as? Bool ?? true
        guard isEnabled else {
            removePendingReminder()
            return
        }

        guard await notificationScheduler.isAuthorized() else {
            removePendingReminder()
            return
        }

        var triggerComponents = DateComponents()
        triggerComponents.hour = Constants.defaultHour
        triggerComponents.minute = Constants.defaultMinute

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Today's Summary")
        content.body = String(localized: "Your daily health summary is ready. Tap to review.")
        content.sound = .default
        content.userInfo = NotificationResponsePayload(
            insightType: HealthInsight.InsightType.dailyDigest.rawValue
        ).userInfo

        let request = UNNotificationRequest(
            identifier: Constants.notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        )

        removePendingReminder()

        do {
            try await notificationScheduler.add(request)
            AppLogger.notification.info("[DailyDigest] Scheduled daily reminder at \(Constants.defaultHour):\(Constants.defaultMinute)")
        } catch {
            AppLogger.notification.error("[DailyDigest] Failed to schedule: \(error.localizedDescription)")
        }
    }

    func removePendingReminder() {
        notificationScheduler.removePendingReminder(identifier: Constants.notificationIdentifier)
    }
}
