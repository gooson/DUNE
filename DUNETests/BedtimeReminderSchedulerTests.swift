import Foundation
import Testing
import UserNotifications
@testable import DUNE

@Suite("BedtimeReminderScheduler")
@MainActor
struct BedtimeReminderSchedulerTests {

    @Test("Schedules reminder using selected lead time", arguments: BedtimeReminderLeadTime.allCases)
    func schedulesReminderUsingSelectedLeadTime(leadTime: BedtimeReminderLeadTime) async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        userDefaults.set(leadTime.rawValue, forKey: BedtimeReminderLeadTime.storageKey)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let sleepService = MockSleepService(
            calendar: calendar,
            referenceDate: now,
            stagesByOffset: [
                1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: now)],
                2: [makeSleepStage(dayOffset: 2, hour: 23, minute: 30, calendar: calendar, referenceDate: now)],
                3: [makeSleepStage(dayOffset: 3, hour: 23, minute: 30, calendar: calendar, referenceDate: now)]
            ]
        )

        let scheduler = BedtimeReminderScheduler(
            sleepService: sleepService,
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        #expect(notificationScheduler.removedIdentifiers == [
            "com.raftel.dune.bedtime-reminder",
            "com.raftel.dune.bedtime-watch-reminder"
        ])
        #expect(notificationScheduler.requests.count == 1)

        let request = try #require(notificationScheduler.requests.first)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        switch leadTime {
        case .thirtyMinutes:
            #expect(trigger.dateComponents.hour == 23)
            #expect(trigger.dateComponents.minute == 0)
        case .oneHour:
            #expect(trigger.dateComponents.hour == 22)
            #expect(trigger.dateComponents.minute == 30)
        case .twoHours:
            #expect(trigger.dateComponents.hour == 21)
            #expect(trigger.dateComponents.minute == 30)
        }
        #expect(request.content.title == "Start winding down now for better recovery tomorrow.")
    }

    @Test("Removes pending reminder without scheduling when disabled")
    func removesReminderWhenDisabled() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        userDefaults.set(false, forKey: BedtimeReminderScheduler.settingsKey)

        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let scheduler = BedtimeReminderScheduler(
            sleepService: MockSleepService(calendar: calendar, referenceDate: now, stagesByOffset: [:]),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        #expect(notificationScheduler.removedIdentifiers == [
            "com.raftel.dune.bedtime-reminder",
            "com.raftel.dune.bedtime-watch-reminder"
        ])
        #expect(notificationScheduler.requests.isEmpty)
    }

    @Test("Removes pending reminder when recent sleep data is unavailable")
    func removesReminderWithoutSleepData() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)

        let scheduler = BedtimeReminderScheduler(
            sleepService: MockSleepService(calendar: calendar, referenceDate: now, stagesByOffset: [:]),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        #expect(notificationScheduler.removedIdentifiers == [
            "com.raftel.dune.bedtime-reminder",
            "com.raftel.dune.bedtime-watch-reminder"
        ])
        #expect(notificationScheduler.requests.isEmpty)
    }

    @Test("Force refresh bypasses debounce after lead time changes")
    func forceRefreshBypassesDebounceAfterLeadTimeChanges() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        userDefaults.set(BedtimeReminderLeadTime.twoHours.rawValue, forKey: BedtimeReminderLeadTime.storageKey)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let sleepService = MockSleepService(
            calendar: calendar,
            referenceDate: now,
            stagesByOffset: [
                1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: now)],
                2: [makeSleepStage(dayOffset: 2, hour: 23, minute: 30, calendar: calendar, referenceDate: now)],
                3: [makeSleepStage(dayOffset: 3, hour: 23, minute: 30, calendar: calendar, referenceDate: now)]
            ]
        )

        let scheduler = BedtimeReminderScheduler(
            sleepService: sleepService,
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        userDefaults.set(BedtimeReminderLeadTime.thirtyMinutes.rawValue, forKey: BedtimeReminderLeadTime.storageKey)
        await scheduler.refreshSchedule()
        #expect(notificationScheduler.requests.count == 1)

        await scheduler.refreshSchedule(force: true)
        #expect(notificationScheduler.requests.count == 2)

        let request = try #require(notificationScheduler.requests.last)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 23)
        #expect(trigger.dateComponents.minute == 0)
    }

    @Test("Force refresh schedules once notification authorization is granted after an earlier skip")
    func forceRefreshSchedulesAfterAuthorizationBecomesAvailable() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        userDefaults.set(BedtimeReminderLeadTime.thirtyMinutes.rawValue, forKey: BedtimeReminderLeadTime.storageKey)

        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: false)
        let sleepService = MockSleepService(
            calendar: calendar,
            referenceDate: now,
            stagesByOffset: [
                1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: now)],
                2: [makeSleepStage(dayOffset: 2, hour: 23, minute: 30, calendar: calendar, referenceDate: now)],
                3: [makeSleepStage(dayOffset: 3, hour: 23, minute: 30, calendar: calendar, referenceDate: now)]
            ]
        )

        let scheduler = BedtimeReminderScheduler(
            sleepService: sleepService,
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()
        #expect(notificationScheduler.requests.isEmpty)

        notificationScheduler.authorized = true
        await scheduler.refreshSchedule(force: true)

        #expect(notificationScheduler.requests.count == 1)
        let request = try #require(notificationScheduler.requests.first)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 23)
        #expect(trigger.dateComponents.minute == 0)
    }

    private func makeUserDefaults() throws -> UserDefaults {
        let suiteName = "BedtimeReminderSchedulerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: BedtimeReminderScheduler.settingsKey)
        return defaults
    }

    private func makeSleepStage(
        dayOffset: Int,
        hour: Int,
        minute: Int,
        durationMinutes: Int = 420,
        calendar: Calendar,
        referenceDate: Date
    ) -> SleepStage {
        let baseDate = calendar.date(byAdding: .day, value: -dayOffset, to: referenceDate) ?? referenceDate
        let start = calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: baseDate
        ) ?? baseDate
        let end = start.addingTimeInterval(Double(durationMinutes * 60))

        return SleepStage(stage: .core, duration: end.timeIntervalSince(start), startDate: start, endDate: end)
    }
}

private struct MockSleepService: SleepQuerying {
    let calendar: Calendar
    let referenceDate: Date
    let stagesByOffset: [Int: [SleepStage]]

    func fetchSleepStages(for date: Date) async throws -> [SleepStage] {
        let offset = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: referenceDate)
        ).day ?? 0
        return stagesByOffset[offset] ?? []
    }

    func fetchLatestSleepStages(withinDays days: Int) async throws -> (stages: [SleepStage], date: Date)? {
        nil
    }

    func fetchDailySleepDurations(
        start: Date,
        end: Date
    ) async throws -> [(date: Date, totalMinutes: Double, stageBreakdown: [SleepStage.Stage: Double])] {
        []
    }

    func fetchLastNightSleepSummary(for date: Date) async throws -> SleepSummary? {
        nil
    }
}

@MainActor
private final class MockBedtimeNotificationScheduler: BedtimeReminderNotificationScheduling {
    var authorized: Bool
    private(set) var requests: [UNNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []

    init(authorized: Bool) {
        self.authorized = authorized
    }

    func isAuthorized() async -> Bool {
        authorized
    }

    func add(_ request: UNNotificationRequest) async throws {
        requests.append(request)
    }

    func removePendingReminder(identifier: String) {
        removedIdentifiers.append(identifier)
    }
}
