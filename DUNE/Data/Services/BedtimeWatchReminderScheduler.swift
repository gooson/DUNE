import Foundation
import UserNotifications

/// Schedules a daily bedtime reminder for users who track sleep with Apple Watch.
@MainActor
final class BedtimeWatchReminderScheduler {
    static let shared = BedtimeWatchReminderScheduler()

    private enum Constants {
        static let notificationIdentifier = "com.raftel.dune.bedtime-watch-reminder"
        static let lookbackDays = 7
        static let leadMinutes = 30
    }

    private let sleepService: SleepQuerying
    private let notificationCenter: UNUserNotificationCenter
    private let bedtimeCalculator: CalculateAverageBedtimeUseCase

    init(
        sleepService: SleepQuerying = SleepQueryService(manager: .shared),
        notificationCenter: UNUserNotificationCenter = .current(),
        bedtimeCalculator: CalculateAverageBedtimeUseCase = .init()
    ) {
        self.sleepService = sleepService
        self.notificationCenter = notificationCenter
        self.bedtimeCalculator = bedtimeCalculator
    }

    func refreshSchedule() async {
        guard WatchSessionManager.shared.isPaired,
              WatchSessionManager.shared.isWatchAppInstalled else {
            await removePendingReminder()
            return
        }

        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            await removePendingReminder()
            return
        }

        let calendar = Calendar.current
        let today = Date()

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
        content.title = String(localized: "Wear your Apple Watch tonight to start tracking your wellness score.")
        content.body = String(localized: "Wear Apple Watch to bed for sleep tracking, or add body composition records to get started.")
        content.sound = .default
        content.categoryIdentifier = "sleepBedtimeReminder"

        let request = UNNotificationRequest(
            identifier: Constants.notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        )

        await removePendingReminder()

        do {
            try await notificationCenter.add(request)
            let hh = triggerComponents.hour ?? 0
            let mm = triggerComponents.minute ?? 0
            AppLogger.notification.info("[BedtimeReminder] Scheduled at \(hh):\(String(format: "%02d", mm))")
        } catch {
            AppLogger.notification.error("[BedtimeReminder] Failed to schedule reminder: \(error.localizedDescription)")
        }
    }

    func removePendingReminder() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Constants.notificationIdentifier])
    }
}
