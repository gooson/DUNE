import Foundation
import UserNotifications

/// Schedules a weekly posture measurement reminder notification.
@MainActor
final class PostureReminderScheduler {
    static let shared = PostureReminderScheduler()
    static let settingsKey = "isPostureReminderEnabled"

    private enum Constants {
        static let notificationIdentifier = "com.raftel.dune.posture-reminder"
        /// Default: Sunday 10:00 AM
        static let defaultWeekday = 1  // Sunday
        static let defaultHour = 10
        static let defaultMinute = 0
    }

    private let notificationScheduler: BedtimeReminderNotificationScheduling
    private let userDefaults: UserDefaults

    init(
        notificationScheduler: BedtimeReminderNotificationScheduling = UserNotificationCenterBedtimeReminderScheduler(),
        userDefaults: UserDefaults = .standard
    ) {
        self.notificationScheduler = notificationScheduler
        self.userDefaults = userDefaults
    }

    func refreshSchedule() async {
        let isEnabled = userDefaults.object(forKey: Self.settingsKey) as? Bool ?? false
        guard isEnabled else {
            removePendingReminder()
            return
        }

        guard await notificationScheduler.isAuthorized() else {
            removePendingReminder()
            return
        }

        var triggerComponents = DateComponents()
        triggerComponents.weekday = Constants.defaultWeekday
        triggerComponents.hour = Constants.defaultHour
        triggerComponents.minute = Constants.defaultMinute

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time for a posture check-up")
        content.body = String(localized: "Regular posture assessments help you track improvements and catch issues early.")
        content.sound = .default
        content.userInfo = NotificationResponsePayload(
            insightType: HealthInsight.InsightType.postureReminder.rawValue
        ).userInfo

        let request = UNNotificationRequest(
            identifier: Constants.notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        )

        removePendingReminder()

        do {
            try await notificationScheduler.add(request)
            AppLogger.notification.info("[PostureReminder] Scheduled weekly reminder")
        } catch {
            AppLogger.notification.error("[PostureReminder] Failed to schedule: \(error.localizedDescription)")
        }
    }

    func removePendingReminder() {
        notificationScheduler.removePendingReminder(identifier: Constants.notificationIdentifier)
    }
}
