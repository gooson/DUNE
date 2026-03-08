import Foundation
import UserNotifications

@MainActor
protocol BedtimeReminderNotificationScheduling {
    func isAuthorized() async -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingReminder(identifier: String)
}

@MainActor
struct UserNotificationCenterBedtimeReminderScheduler: BedtimeReminderNotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingReminder(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

/// Schedules a daily bedtime reminder based on the user's recent average bedtime.
@MainActor
final class BedtimeReminderScheduler {
    static let shared = BedtimeReminderScheduler()
    static let settingsKey = "isBedtimeWatchReminderEnabled"

    private enum Constants {
        static let notificationIdentifier = "com.raftel.dune.bedtime-reminder"
        static let lookbackDays = 7
        static let leadMinutes = 120
    }

    private let sleepService: SleepQuerying
    private let notificationScheduler: BedtimeReminderNotificationScheduling
    private let bedtimeCalculator: CalculateAverageBedtimeUseCase
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private var lastRefreshDate: Date?

    init(
        sleepService: SleepQuerying = SleepQueryService(manager: .shared),
        notificationScheduler: BedtimeReminderNotificationScheduling = UserNotificationCenterBedtimeReminderScheduler(),
        bedtimeCalculator: CalculateAverageBedtimeUseCase = .init(),
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.sleepService = sleepService
        self.notificationScheduler = notificationScheduler
        self.bedtimeCalculator = bedtimeCalculator
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.now = now
    }

    func refreshSchedule() async {
        let currentDate = now()
        if let last = lastRefreshDate, currentDate.timeIntervalSince(last) < 30 * 60 { return }
        lastRefreshDate = currentDate

        let isEnabled = userDefaults.object(forKey: Self.settingsKey) as? Bool ?? true
        guard isEnabled else {
            await removePendingReminder()
            return
        }

        guard await notificationScheduler.isAuthorized() else {
            await removePendingReminder()
            return
        }

        let today = currentDate

        let recentStages: [[SleepStage]] = await withTaskGroup(
            of: (Int, [SleepStage])?.self
        ) { [sleepService] group in
            for offset in 1...Constants.lookbackDays {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                group.addTask {
                    do {
                        let stages = try await sleepService.fetchSleepStages(for: date)
                        return stages.isEmpty ? nil : (offset, stages)
                    } catch {
                        AppLogger.notification.error("[BedtimeReminder] Failed to fetch sleep for day offset \(offset): \(error.localizedDescription)")
                        return nil
                    }
                }
            }

            var results: [(Int, [SleepStage])] = []
            for await result in group {
                if let result { results.append(result) }
            }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }

        guard let bedtime = bedtimeCalculator.execute(
            input: .init(sleepStagesByDay: recentStages, calendar: calendar)
        ) else {
            await removePendingReminder()
            return
        }

        let bedtimeMinutes = (bedtime.hour ?? 0) * 60 + (bedtime.minute ?? 0)
        let triggerMinutes = (bedtimeMinutes - Constants.leadMinutes + (24 * 60)) % (24 * 60)

        var triggerComponents = DateComponents()
        triggerComponents.hour = triggerMinutes / 60
        triggerComponents.minute = triggerMinutes % 60

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Start winding down now for better recovery tomorrow.")
        content.body = String(localized: "Heading to bed around your usual time can improve sleep quality, recovery, and workout consistency.")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Constants.notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        )

        await removePendingReminder()

        do {
            try await notificationScheduler.add(request)
            let hh = triggerComponents.hour ?? 0
            let mm = triggerComponents.minute ?? 0
            AppLogger.notification.info("[BedtimeReminder] Scheduled at \(hh):\(String(format: "%02d", mm))")
        } catch {
            AppLogger.notification.error("[BedtimeReminder] Failed to schedule reminder: \(error.localizedDescription)")
        }
    }

    func removePendingReminder() async {
        notificationScheduler.removePendingReminder(identifier: Constants.notificationIdentifier)
    }
}
