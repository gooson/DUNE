import Foundation
import Testing
import UserNotifications
@testable import DUNE

@Suite("BedtimeReminderScheduler")
@MainActor
struct BedtimeReminderSchedulerTests {
    private let expectedTitle = String(localized: "Put on your Apple Watch before bed.")

    @Test("Schedules reminder using selected lead time", arguments: BedtimeReminderLeadTime.allCases)
    func schedulesReminderUsingSelectedLeadTime(leadTime: BedtimeReminderLeadTime) async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        userDefaults.set(leadTime.rawValue, forKey: BedtimeReminderLeadTime.storageKey)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let watchWearStateService = MockWatchWearStateService(response: false)
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
            watchWearStateService: watchWearStateService,
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
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
        let triggerDate = try triggerDate(for: request, calendar: calendar)
        switch leadTime {
        case .thirtyMinutes:
            let expected = try expectedDate(year: 2026, month: 3, day: 8, hour: 23, minute: 0, calendar: calendar)
            #expect(triggerDate == expected)
        case .oneHour:
            let expected = try expectedDate(year: 2026, month: 3, day: 8, hour: 22, minute: 30, calendar: calendar)
            #expect(triggerDate == expected)
        case .twoHours:
            let expected = try expectedDate(year: 2026, month: 3, day: 8, hour: 21, minute: 30, calendar: calendar)
            #expect(triggerDate == expected)
        }
        #expect(request.content.title == expectedTitle)
        #expect(await watchWearStateService.queryCount() == 0)
    }

    @Test("Uses one hour default lead time when no selection is stored")
    func usesOneHourDefaultLeadTimeWhenSelectionMissing() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)

        let scheduler = BedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: now,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: now)]
                ]
            ),
            watchWearStateService: MockWatchWearStateService(response: false),
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        let request = try #require(notificationScheduler.requests.first)
        let triggerDate = try triggerDate(for: request, calendar: calendar)
        let expected = try expectedDate(year: 2026, month: 3, day: 8, hour: 22, minute: 30, calendar: calendar)
        #expect(triggerDate == expected)
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
            watchWearStateService: MockWatchWearStateService(response: false),
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
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
            watchWearStateService: MockWatchWearStateService(response: false),
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
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
        let watchWearStateService = MockWatchWearStateService(response: false)
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
            watchWearStateService: watchWearStateService,
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
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
        let triggerDate = try triggerDate(for: request, calendar: calendar)
        let expected = try expectedDate(year: 2026, month: 3, day: 8, hour: 23, minute: 0, calendar: calendar)
        #expect(triggerDate == expected)
        #expect(await watchWearStateService.queryCount() == 0)
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
            watchWearStateService: MockWatchWearStateService(response: false),
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
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
        let triggerDate = try triggerDate(for: request, calendar: calendar)
        let expected = try expectedDate(year: 2026, month: 3, day: 8, hour: 23, minute: 0, calendar: calendar)
        #expect(triggerDate == expected)
    }

    @Test("Schedules tomorrow when today's reminder time already passed")
    func schedulesTomorrowWhenTodayHasPassed() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23, minute: 10)))
        let userDefaults = try makeUserDefaults()
        userDefaults.set(BedtimeReminderLeadTime.thirtyMinutes.rawValue, forKey: BedtimeReminderLeadTime.storageKey)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)

        let scheduler = BedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: now,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: now)]
                ]
            ),
            watchWearStateService: MockWatchWearStateService(response: false),
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        let request = try #require(notificationScheduler.requests.first)
        let triggerDate = try triggerDate(for: request, calendar: calendar)
        let expected = try expectedDate(year: 2026, month: 3, day: 9, hour: 23, minute: 0, calendar: calendar)
        #expect(triggerDate == expected)
    }

    @Test("Does not skip tonight's reminder just because watch data exists earlier in the day")
    func doesNotSkipEarlierDayReminderWhenWatchDataExists() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let watchWearStateService = MockWatchWearStateService(response: true)

        let scheduler = BedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: now,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: now)]
                ]
            ),
            watchWearStateService: watchWearStateService,
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        #expect(notificationScheduler.requests.count == 1)
        #expect(await watchWearStateService.queryCount() == 0)
    }

    @Test("Removes reminder when watch is likely worn near the trigger time")
    func removesReminderWhenWatchLikelyWornNearTrigger() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 22, minute: 10)))
        let userDefaults = try makeUserDefaults()
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let watchWearStateService = MockWatchWearStateService(response: true)

        let scheduler = BedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: now,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: now)]
                ]
            ),
            watchWearStateService: watchWearStateService,
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule(force: true)

        #expect(notificationScheduler.requests.isEmpty)
        #expect(await watchWearStateService.queryCount() == 1)
    }

    @Test("Removes reminder when Apple Watch is unavailable")
    func removesReminderWhenWatchUnavailable() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)

        let scheduler = BedtimeReminderScheduler(
            sleepService: MockSleepService(calendar: calendar, referenceDate: now, stagesByOffset: [:]),
            watchWearStateService: MockWatchWearStateService(response: false),
            watchAvailabilityProvider: MockWatchAvailabilityProvider(isPaired: false, isWatchAppInstalled: false),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        #expect(notificationScheduler.requests.isEmpty)
        #expect(notificationScheduler.removedIdentifiers == [
            "com.raftel.dune.bedtime-reminder",
            "com.raftel.dune.bedtime-watch-reminder"
        ])
    }

    @Test("Schedules reminder when watch is paired even if companion app is not installed")
    func schedulesReminderWithoutCompanionAppInstalled() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)

        let scheduler = BedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: now,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: now)]
                ]
            ),
            watchWearStateService: MockWatchWearStateService(response: false),
            watchAvailabilityProvider: MockWatchAvailabilityProvider(isPaired: true, isWatchAppInstalled: false),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        #expect(notificationScheduler.requests.count == 1)
    }

    private func triggerDate(for request: UNNotificationRequest, calendar: Calendar) throws -> Date {
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        return try #require(calendar.date(from: trigger.dateComponents))
    }

    private func expectedDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
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

private actor MockWatchWearStateService: WatchWearStateQuerying {
    private let response: Bool
    private var intervals: [(Date, Date)] = []

    init(response: Bool) {
        self.response = response
    }

    func hasRecentWatchHeartRateSample(startingAt startDate: Date, endingAt endDate: Date) async -> Bool {
        intervals.append((startDate, endDate))
        return response
    }

    func queryCount() -> Int {
        intervals.count
    }
}

@MainActor
private struct MockWatchAvailabilityProvider: BedtimeReminderWatchAvailabilityProviding {
    var isPaired = true
    var isWatchAppInstalled = true
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
