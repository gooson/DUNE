import Foundation
import UserNotifications
import WatchConnectivity

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

@MainActor
protocol BedtimeReminderWatchAvailabilityProviding {
    var isPaired: Bool { get }
}

@MainActor
struct WatchConnectivityBedtimeReminderWatchAvailabilityProvider: BedtimeReminderWatchAvailabilityProviding {
    var isPaired: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isPaired
    }
}

/// Schedules the next bedtime reminder based on the user's recent average bedtime.
@MainActor
final class BedtimeReminderScheduler {
    static let shared = BedtimeReminderScheduler()
    static let settingsKey = "isBedtimeWatchReminderEnabled"

    private enum Constants {
        static let legacyNotificationIdentifier = "com.raftel.dune.bedtime-watch-reminder"
        static let notificationIdentifier = "com.raftel.dune.bedtime-reminder"
        static let lookbackDays = 7
        static let watchWearLookbackInterval: TimeInterval = 90 * 60
    }

    private let sleepService: SleepQuerying
    private let watchWearStateService: WatchWearStateQuerying
    private let watchAvailabilityProvider: BedtimeReminderWatchAvailabilityProviding
    private let notificationScheduler: BedtimeReminderNotificationScheduling
    private let bedtimeCalculator: CalculateAverageBedtimeUseCase
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date
    private var lastRefreshDate: Date?

    init(
        sleepService: SleepQuerying = SleepQueryService(manager: .shared),
        watchWearStateService: WatchWearStateQuerying = HeartRateQueryService(manager: .shared),
        watchAvailabilityProvider: BedtimeReminderWatchAvailabilityProviding = WatchConnectivityBedtimeReminderWatchAvailabilityProvider(),
        notificationScheduler: BedtimeReminderNotificationScheduling = UserNotificationCenterBedtimeReminderScheduler(),
        bedtimeCalculator: CalculateAverageBedtimeUseCase = .init(),
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.sleepService = sleepService
        self.watchWearStateService = watchWearStateService
        self.watchAvailabilityProvider = watchAvailabilityProvider
        self.notificationScheduler = notificationScheduler
        self.bedtimeCalculator = bedtimeCalculator
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.now = now
    }

    func refreshSchedule(force: Bool = false) async {
        let currentDate = now()
        if !force,
           let last = lastRefreshDate,
           currentDate.timeIntervalSince(last) < 30 * 60 {
            return
        }
        lastRefreshDate = currentDate

        let isEnabled = userDefaults.object(forKey: Self.settingsKey) as? Bool ?? true
        guard isEnabled else {
            await removePendingReminder()
            return
        }

        guard watchAvailabilityProvider.isPaired else {
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

        let leadTime = configuredLeadTime()
        let bedtimeMinutes = (bedtime.hour ?? 0) * 60 + (bedtime.minute ?? 0)
        let triggerMinutes = (bedtimeMinutes - leadTime.minutes + (24 * 60)) % (24 * 60)
        guard let triggerDate = nextTriggerDate(triggerMinutes: triggerMinutes, from: currentDate) else {
            await removePendingReminder()
            return
        }

        if await shouldSkipReminderBecauseWatchIsLikelyWorn(
            currentDate: currentDate,
            triggerDate: triggerDate
        ) {
            await removePendingReminder()
            AppLogger.notification.info("[BedtimeReminder] Skipped because Apple Watch appears to be worn near bedtime")
            return
        }

        let triggerComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Put on your Apple Watch before bed.")
        content.body = String(localized: "Wear your Apple Watch to bed to track sleep.")
        content.sound = .default
        content.userInfo = NotificationResponsePayload(
            routeKind: NotificationRoute.sleepDetail.destination.rawValue,
            insightType: HealthInsight.InsightType.sleepComplete.rawValue
        ).userInfo

        let request = UNNotificationRequest(
            identifier: Constants.notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        )

        await removePendingReminder()

        do {
            try await notificationScheduler.add(request)
            AppLogger.notification.info("[BedtimeReminder] Scheduled for \(triggerDate.formatted(date: .abbreviated, time: .shortened))")
        } catch {
            AppLogger.notification.error("[BedtimeReminder] Failed to schedule reminder: \(error.localizedDescription)")
        }
    }

    func removePendingReminder() async {
        notificationScheduler.removePendingReminder(identifier: Constants.notificationIdentifier)
        notificationScheduler.removePendingReminder(identifier: Constants.legacyNotificationIdentifier)
    }

    private func configuredLeadTime() -> BedtimeReminderLeadTime {
        guard let rawValue = userDefaults.object(forKey: BedtimeReminderLeadTime.storageKey) as? Int,
              let leadTime = BedtimeReminderLeadTime(rawValue: rawValue) else {
            return BedtimeReminderLeadTime.defaultValue
        }
        return leadTime
    }

    private func nextTriggerDate(triggerMinutes: Int, from referenceDate: Date) -> Date? {
        let startOfDay = calendar.startOfDay(for: referenceDate)
        guard let todayTrigger = calendar.date(byAdding: .minute, value: triggerMinutes, to: startOfDay) else {
            return nil
        }

        if todayTrigger > referenceDate {
            return todayTrigger
        }

        return calendar.date(byAdding: .day, value: 1, to: todayTrigger)
    }

    private func shouldSkipReminderBecauseWatchIsLikelyWorn(
        currentDate: Date,
        triggerDate: Date
    ) async -> Bool {
        let evaluationWindowStart = triggerDate.addingTimeInterval(-Constants.watchWearLookbackInterval)
        guard currentDate >= evaluationWindowStart, currentDate < triggerDate else {
            return false
        }

        let sampleWindowStart = max(
            evaluationWindowStart,
            currentDate.addingTimeInterval(-Constants.watchWearLookbackInterval)
        )

        return await watchWearStateService.hasRecentWatchHeartRateSample(
            startingAt: sampleWindowStart,
            endingAt: currentDate
        )
    }
}
