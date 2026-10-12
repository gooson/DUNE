import Foundation
import Testing
import UserNotifications
@testable import DUNE

@Suite("BedtimeReminderScheduler")
@MainActor
struct BedtimeReminderSchedulerTests {
    private let expectedTitle = String(localized: "Start winding down now for better recovery tomorrow.")

    @Test("Schedules reminder using selected lead time", arguments: BedtimeReminderLeadTime.allCases)
    func schedulesReminderUsingSelectedLeadTime(leadTime: BedtimeReminderLeadTime) async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        userDefaults.set(leadTime.rawValue, forKey: BedtimeReminderLeadTime.generalStorageKey)
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
            "com.raftel.dune.bedtime-reminder"
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
    }

    @Test("Uses two hour default lead time when no selection is stored")
    func usesTwoHourDefaultLeadTimeWhenSelectionMissing() async throws {
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
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        let request = try #require(notificationScheduler.requests.first)
        let triggerDate = try triggerDate(for: request, calendar: calendar)
        let expected = try expectedDate(year: 2026, month: 3, day: 8, hour: 21, minute: 30, calendar: calendar)
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
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        #expect(notificationScheduler.removedIdentifiers == [
            "com.raftel.dune.bedtime-reminder"
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
            "com.raftel.dune.bedtime-reminder"
        ])
        #expect(notificationScheduler.requests.isEmpty)
    }

    @Test("Force refresh bypasses debounce after lead time changes")
    func forceRefreshBypassesDebounceAfterLeadTimeChanges() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        userDefaults.set(BedtimeReminderLeadTime.twoHours.rawValue, forKey: BedtimeReminderLeadTime.generalStorageKey)
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

        userDefaults.set(BedtimeReminderLeadTime.thirtyMinutes.rawValue, forKey: BedtimeReminderLeadTime.generalStorageKey)
        await scheduler.refreshSchedule()
        #expect(notificationScheduler.requests.count == 1)

        await scheduler.refreshSchedule(force: true)
        #expect(notificationScheduler.requests.count == 2)

        let request = try #require(notificationScheduler.requests.last)
        let triggerDate = try triggerDate(for: request, calendar: calendar)
        let expected = try expectedDate(year: 2026, month: 3, day: 8, hour: 23, minute: 0, calendar: calendar)
        #expect(triggerDate == expected)
    }

    @Test("Force refresh schedules once notification authorization is granted after an earlier skip")
    func forceRefreshSchedulesAfterAuthorizationBecomesAvailable() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        userDefaults.set(BedtimeReminderLeadTime.thirtyMinutes.rawValue, forKey: BedtimeReminderLeadTime.generalStorageKey)

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
        let triggerDate = try triggerDate(for: request, calendar: calendar)
        let expected = try expectedDate(year: 2026, month: 3, day: 8, hour: 23, minute: 0, calendar: calendar)
        #expect(triggerDate == expected)
    }

    @Test("Schedules tomorrow when today's reminder time already passed")
    func schedulesTomorrowWhenTodayHasPassed() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23, minute: 10)))
        let userDefaults = try makeUserDefaults()
        userDefaults.set(BedtimeReminderLeadTime.thirtyMinutes.rawValue, forKey: BedtimeReminderLeadTime.generalStorageKey)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)

        let scheduler = BedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: now,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: now)]
                ]
            ),
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

@Suite("AppleWatchBedtimeReminderScheduler")
@MainActor
struct AppleWatchBedtimeReminderSchedulerTests {
    private let expectedTitle = String(localized: "Check your Apple Watch before bed.")
    private let expectedBody = String(localized: "To track sleep, make sure your Apple Watch is on your wrist.")

    @Test("Schedules reminder using selected lead time", arguments: BedtimeReminderLeadTime.allCases)
    func schedulesReminderUsingSelectedLeadTime(leadTime: BedtimeReminderLeadTime) async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults(enabled: true)
        userDefaults.set(leadTime.rawValue, forKey: BedtimeReminderLeadTime.watchStorageKey)
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

        let scheduler = AppleWatchBedtimeReminderScheduler(
            sleepService: sleepService,
            watchWearStateService: watchWearStateService,
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        #expect(notificationScheduler.removedIdentifiers.isEmpty)
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
        #expect(request.content.body == expectedBody)
        #expect(await watchWearStateService.queryCount() == 0)
    }

    @Test("Uses one hour default lead time when no selection is stored")
    func usesOneHourDefaultLeadTimeWhenSelectionMissing() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults(enabled: true)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)

        let scheduler = AppleWatchBedtimeReminderScheduler(
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

    @Test("Schedules reminder when enabled by default")
    func schedulesReminderWhenEnabledByDefault() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults()
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)

        let scheduler = AppleWatchBedtimeReminderScheduler(
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

        #expect(notificationScheduler.requests.count == 1)
    }

    @Test("Removes pending reminder when disabled")
    func removesReminderWhenDisabled() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults(enabled: false)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)

        let scheduler = AppleWatchBedtimeReminderScheduler(
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
            "com.raftel.dune.bedtime-watch-reminder"
        ])
        #expect(notificationScheduler.requests.isEmpty)
    }

    @Test("Force refresh schedules once notification authorization is granted after an earlier skip")
    func forceRefreshSchedulesAfterAuthorizationBecomesAvailable() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults(enabled: true)
        userDefaults.set(BedtimeReminderLeadTime.thirtyMinutes.rawValue, forKey: BedtimeReminderLeadTime.watchStorageKey)

        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: false)
        let sleepService = MockSleepService(
            calendar: calendar,
            referenceDate: now,
            stagesByOffset: [
                1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: now)]
            ]
        )

        let scheduler = AppleWatchBedtimeReminderScheduler(
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

    @Test("Does not skip tonight's reminder just because watch data exists earlier in the day")
    func doesNotSkipEarlierDayReminderWhenWatchDataExists() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults(enabled: true)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let watchWearStateService = MockWatchWearStateService(response: true)

        let scheduler = AppleWatchBedtimeReminderScheduler(
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
        let userDefaults = try makeUserDefaults(enabled: true)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let watchWearStateService = MockWatchWearStateService(response: true)

        let scheduler = AppleWatchBedtimeReminderScheduler(
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

    @Test("A watch heart-rate update cancels a reminder scheduled earlier in the day")
    func heartRateUpdateCancelsScheduledReminder() async throws {
        let calendar = Calendar(identifier: .gregorian)
        var currentDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults(enabled: true)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let watchWearStateService = MockWatchWearStateService(response: true)
        let identifier = "com.raftel.dune.bedtime-watch-reminder"

        let scheduler = AppleWatchBedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: currentDate,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: currentDate)]
                ]
            ),
            watchWearStateService: watchWearStateService,
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { currentDate }
        )

        await scheduler.refreshSchedule()
        #expect(notificationScheduler.pendingRequests[identifier] != nil)

        await scheduler.cancelPendingReminderIfWatchIsWorn()
        #expect(notificationScheduler.pendingRequests[identifier] != nil)
        #expect(notificationScheduler.pendingLookups == 0)
        #expect(await watchWearStateService.queryCount() == 0)

        currentDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 22, minute: 10)))
        await scheduler.cancelPendingReminderIfWatchIsWorn()

        #expect(notificationScheduler.pendingRequests[identifier] == nil)
        #expect(notificationScheduler.pendingLookups == 1)
        #expect(await watchWearStateService.queryCount() == 1)
    }

    @Test("A Watch update during notification registration cancels the newly added reminder")
    func heartRateUpdateDuringRegistrationCancelsReminder() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let currentDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 22)))
        let addGate = NotificationAddGate()
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        notificationScheduler.addGate = addGate
        let watchWearStateService = MockWatchWearStateService(response: false)
        let identifier = "com.raftel.dune.bedtime-watch-reminder"

        let scheduler = AppleWatchBedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: currentDate,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: currentDate)]
                ]
            ),
            watchWearStateService: watchWearStateService,
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
            notificationScheduler: notificationScheduler,
            userDefaults: try makeUserDefaults(enabled: true),
            calendar: calendar,
            now: { currentDate }
        )

        let refresh = Task { await scheduler.refreshSchedule() }
        await addGate.waitUntilStarted()
        await watchWearStateService.setResponse(true)
        let recheck = Task { await scheduler.cancelPendingReminderIfWatchIsWorn() }

        await addGate.release()
        await refresh.value
        await recheck.value

        #expect(notificationScheduler.pendingRequests[identifier] == nil)
        #expect(notificationScheduler.pendingLookups == 1)
        #expect(await watchWearStateService.queryCount() == 2)
    }

    @Test("A new Watch sample arriving during a wear query is rechecked")
    func heartRateUpdateDuringWearQueryIsRechecked() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let currentDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 22)))
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let watchWearStateService = MockWatchWearStateService(response: false)
        let identifier = "com.raftel.dune.bedtime-watch-reminder"

        let scheduler = AppleWatchBedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: currentDate,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: currentDate)]
                ]
            ),
            watchWearStateService: watchWearStateService,
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
            notificationScheduler: notificationScheduler,
            userDefaults: try makeUserDefaults(enabled: true),
            calendar: calendar,
            now: { currentDate }
        )

        await scheduler.refreshSchedule()
        #expect(notificationScheduler.pendingRequests[identifier] != nil)

        let queryGate = NotificationAddGate()
        await watchWearStateService.setQueryGate(queryGate)
        let firstUpdate = Task { await scheduler.cancelPendingReminderIfWatchIsWorn() }
        await queryGate.waitUntilStarted()
        await watchWearStateService.setResponse(true)
        let secondUpdate = Task { await scheduler.cancelPendingReminderIfWatchIsWorn() }
        await Task.yield()

        await queryGate.release()
        await firstUpdate.value
        await secondUpdate.value

        #expect(notificationScheduler.pendingRequests[identifier] == nil)
        #expect(await watchWearStateService.queryCount() == 3)
    }

    @Test("A heart-rate update without Watch data keeps the scheduled reminder")
    func nonWatchHeartRateKeepsScheduledReminder() async throws {
        let calendar = Calendar(identifier: .gregorian)
        var currentDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let watchWearStateService = MockWatchWearStateService(response: false)
        let identifier = "com.raftel.dune.bedtime-watch-reminder"

        let scheduler = AppleWatchBedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: currentDate,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: currentDate)]
                ]
            ),
            watchWearStateService: watchWearStateService,
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
            notificationScheduler: notificationScheduler,
            userDefaults: try makeUserDefaults(enabled: true),
            calendar: calendar,
            now: { currentDate }
        )

        await scheduler.refreshSchedule()
        currentDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 22, minute: 10)))
        await scheduler.cancelPendingReminderIfWatchIsWorn()

        #expect(notificationScheduler.pendingRequests[identifier] != nil)
        #expect(await watchWearStateService.queryCount() == 1)
    }

    @Test("Foreground refresh rechecks Watch wear even inside the schedule debounce")
    func debouncedRefreshCancelsWornWatchReminder() async throws {
        let calendar = Calendar(identifier: .gregorian)
        var currentDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 22)))
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)
        let watchWearStateService = MockWatchWearStateService(response: false)
        let identifier = "com.raftel.dune.bedtime-watch-reminder"

        let scheduler = AppleWatchBedtimeReminderScheduler(
            sleepService: MockSleepService(
                calendar: calendar,
                referenceDate: currentDate,
                stagesByOffset: [
                    1: [makeSleepStage(dayOffset: 1, hour: 23, minute: 30, calendar: calendar, referenceDate: currentDate)]
                ]
            ),
            watchWearStateService: watchWearStateService,
            watchAvailabilityProvider: MockWatchAvailabilityProvider(),
            notificationScheduler: notificationScheduler,
            userDefaults: try makeUserDefaults(enabled: true),
            calendar: calendar,
            now: { currentDate }
        )

        await scheduler.refreshSchedule()
        #expect(notificationScheduler.pendingRequests[identifier] != nil)

        await watchWearStateService.setResponse(true)
        currentDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 22, minute: 10)))
        await scheduler.refreshSchedule()

        #expect(notificationScheduler.pendingRequests[identifier] == nil)
        #expect(notificationScheduler.requests.count == 1)
    }

    @Test("Removes reminder when Apple Watch is unavailable")
    func removesReminderWhenWatchUnavailable() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
        let userDefaults = try makeUserDefaults(enabled: true)
        let notificationScheduler = MockBedtimeNotificationScheduler(authorized: true)

        let scheduler = AppleWatchBedtimeReminderScheduler(
            sleepService: MockSleepService(calendar: calendar, referenceDate: now, stagesByOffset: [:]),
            watchWearStateService: MockWatchWearStateService(response: false),
            watchAvailabilityProvider: MockWatchAvailabilityProvider(isPaired: false),
            notificationScheduler: notificationScheduler,
            userDefaults: userDefaults,
            calendar: calendar,
            now: { now }
        )

        await scheduler.refreshSchedule()

        #expect(notificationScheduler.requests.isEmpty)
        #expect(notificationScheduler.removedIdentifiers == [
            "com.raftel.dune.bedtime-watch-reminder"
        ])
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

    private func makeUserDefaults(enabled: Bool? = nil) throws -> UserDefaults {
        let suiteName = "AppleWatchBedtimeReminderSchedulerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        if let enabled {
            defaults.set(enabled, forKey: AppleWatchBedtimeReminderScheduler.settingsKey)
        }
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
    private var response: Bool
    private var intervals: [(Date, Date)] = []
    private var queryGate: NotificationAddGate?

    init(response: Bool) {
        self.response = response
    }

    func hasRecentWatchHeartRateSample(startingAt startDate: Date, endingAt endDate: Date) async -> Bool {
        intervals.append((startDate, endDate))
        let result = response
        let gate = queryGate
        queryGate = nil
        await gate?.wait()
        return result
    }

    func queryCount() -> Int {
        intervals.count
    }

    func setResponse(_ value: Bool) {
        response = value
    }

    func setQueryGate(_ gate: NotificationAddGate) {
        queryGate = gate
    }
}

@MainActor
private struct MockWatchAvailabilityProvider: BedtimeReminderWatchAvailabilityProviding {
    var isPaired = true
}

@MainActor
private final class MockBedtimeNotificationScheduler: BedtimeReminderNotificationScheduling {
    var authorized: Bool
    var addGate: NotificationAddGate?
    private(set) var requests: [UNNotificationRequest] = []
    private(set) var pendingRequests: [String: UNNotificationRequest] = [:]
    private(set) var removedIdentifiers: [String] = []
    private(set) var pendingLookups = 0

    init(authorized: Bool) {
        self.authorized = authorized
    }

    func isAuthorized() async -> Bool {
        authorized
    }

    func add(_ request: UNNotificationRequest) async throws {
        await addGate?.wait()
        requests.append(request)
        pendingRequests[request.identifier] = request
    }

    func pendingReminder(identifier: String) async -> UNNotificationRequest? {
        pendingLookups += 1
        return pendingRequests[identifier]
    }

    func removePendingReminder(identifier: String) {
        removedIdentifiers.append(identifier)
        pendingRequests.removeValue(forKey: identifier)
    }
}

private actor NotificationAddGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
    }

    func waitUntilStarted() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
