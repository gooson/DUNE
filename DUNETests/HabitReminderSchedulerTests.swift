import Foundation
import Testing
import UserNotifications
@testable import DUNE

@Suite("HabitReminderScheduler")
@MainActor
struct HabitReminderSchedulerTests {
    private let habitID = UUID(uuidString: "13FC9DC5-0133-4F3E-8E5F-340986FF0F46")!
    private let calendar = Calendar(identifier: .gregorian)

    @Test("Daily and weekly goals schedule one daily repeating reminder")
    func goalFrequenciesRepeatEveryDay() throws {
        let now = try date(2026, 9, 27, 12, 0)

        for frequency: HabitFrequency in [.daily, .weekly(targetDays: 3)] {
            let requests = HabitReminderScheduler.makeRequests(
                habitID: habitID,
                habitName: "Read",
                frequency: frequency,
                nextDueDate: nil,
                isArchived: false,
                reminderHour: 8,
                reminderMinute: 30,
                now: now,
                calendar: calendar
            )

            #expect(requests.count == 1)
            let request = try #require(requests.first)
            let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
            #expect(trigger.repeats)
            #expect(trigger.dateComponents.hour == 8)
            #expect(trigger.dateComponents.minute == 30)
            #expect(trigger.dateComponents.weekday == nil)
            #expect(trigger.dateComponents.day == nil)
            #expect(request.identifier == "dune.life.habit.\(habitID.uuidString).0d")
            let habitName = "Read"
            #expect(request.content.body == String(localized: "\(habitName) is due today"))
        }
    }

    @Test("Interval reminders retain future due offsets and omit elapsed offsets")
    func intervalOffsets() throws {
        let now = try date(2026, 9, 27, 12, 0)
        let due = try date(2026, 9, 29, 0, 0)
        let requests = HabitReminderScheduler.makeRequests(
            habitID: habitID,
            habitName: "Water plants",
            frequency: .interval(days: 7),
            nextDueDate: due,
            isArchived: false,
            reminderHour: 9,
            reminderMinute: 15,
            now: now,
            calendar: calendar
        )

        #expect(requests.map(\.identifier) == [
            "dune.life.habit.\(habitID.uuidString).1d",
            "dune.life.habit.\(habitID.uuidString).0d"
        ])
        for request in requests {
            let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
            #expect(!trigger.repeats)
            #expect(trigger.dateComponents.hour == 9)
            #expect(trigger.dateComponents.minute == 15)
        }

        let afterAdvance = HabitReminderScheduler.makeRequests(
            habitID: habitID,
            habitName: "Water plants",
            frequency: .interval(days: 7),
            nextDueDate: due,
            isArchived: false,
            reminderHour: 9,
            reminderMinute: 15,
            now: try date(2026, 9, 28, 12, 0),
            calendar: calendar
        )
        #expect(afterAdvance.map(\.identifier) == ["dune.life.habit.\(habitID.uuidString).0d"])

        let atDueTime = HabitReminderScheduler.makeRequests(
            habitID: habitID,
            habitName: "Water plants",
            frequency: .interval(days: 7),
            nextDueDate: due,
            isArchived: false,
            reminderHour: 9,
            reminderMinute: 15,
            now: try date(2026, 9, 29, 9, 15),
            calendar: calendar
        )
        #expect(atDueTime.isEmpty)
    }

    @Test("Reminder time is clamped to valid clock components")
    func clampsReminderTime() throws {
        let requests = HabitReminderScheduler.makeRequests(
            habitID: habitID,
            habitName: "Read",
            frequency: .daily,
            nextDueDate: nil,
            isArchived: false,
            reminderHour: 28,
            reminderMinute: -3
        )
        let request = try #require(requests.first)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.hour == 23)
        #expect(trigger.dateComponents.minute == 0)
    }

    @Test("Archived and unstarted interval habits create no requests")
    func inactiveHabits() throws {
        let now = try date(2026, 9, 27, 12, 0)
        let due = try date(2026, 9, 30, 0, 0)
        let archived = HabitReminderScheduler.makeRequests(
            habitID: habitID,
            habitName: "Read",
            frequency: .daily,
            nextDueDate: due,
            isArchived: true,
            now: now,
            calendar: calendar
        )
        let unstarted = HabitReminderScheduler.makeRequests(
            habitID: habitID,
            habitName: "Read",
            frequency: .interval(days: 7),
            nextDueDate: nil,
            isArchived: false,
            now: now,
            calendar: calendar
        )

        #expect(archived.isEmpty)
        #expect(unstarted.isEmpty)
    }

    @Test("Overlapping refresh and cancellation preserve the enqueue order")
    func overlappingOperations() async throws {
        let client = PausingHabitNotificationClient()
        let scheduler = HabitReminderScheduler(client: client)
        let now = try date(2026, 9, 27, 12, 0)
        let first = HabitReminderScheduler.makeRequests(
            habitID: habitID,
            habitName: "First",
            frequency: .daily,
            nextDueDate: nil,
            isArchived: false,
            now: now,
            calendar: calendar
        )
        let second = HabitReminderScheduler.makeRequests(
            habitID: habitID,
            habitName: "Second",
            frequency: .weekly(targetDays: 4),
            nextDueDate: nil,
            isArchived: false,
            now: now,
            calendar: calendar
        )

        scheduler.enqueueRefresh(habitID: habitID, requests: first)
        await client.waitForFirstAdd()
        scheduler.enqueueRefresh(habitID: habitID, requests: second)
        scheduler.enqueueRemoval(habitID: habitID)
        client.releaseFirstAdd()
        await scheduler.waitForPendingOperations()

        #expect(client.pending.isEmpty)
        #expect(client.events == [
            "add:\(first[0].content.body)",
            "remove:1",
            "add:\(second[0].content.body)",
            "remove:1"
        ])
    }

    @Test("Orphan cleanup removes only reminders for deleted habits")
    func orphanCleanup() async {
        let validID = habitID
        let orphanID = UUID(uuidString: "C10FA905-8F51-4B3D-90BB-9D116195AA8D")!
        let validReminder = "dune.life.habit.\(validID.uuidString).0d"
        let orphanReminder = "dune.life.habit.\(orphanID.uuidString).1d"
        let unrelatedReminder = "com.raftel.dune.bedtime-reminder"
        let malformedReminder = "dune.life.habit.not-a-uuid.0d"
        let client = PausingHabitNotificationClient(shouldPauseFirstAdd: false)
        client.seedPendingRequests(identifiers: [
            validReminder, orphanReminder, unrelatedReminder, malformedReminder
        ])
        let scheduler = HabitReminderScheduler(client: client)

        scheduler.enqueueOrphanCleanup(validHabitIDs: [validID])
        await scheduler.waitForPendingOperations()

        #expect(Set(client.pending.map(\.identifier)) == [
            validReminder, unrelatedReminder, malformedReminder
        ])
        #expect(client.events == ["remove:1"])
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}

@MainActor
private final class PausingHabitNotificationClient: HabitReminderNotificationScheduling {
    private(set) var pending: [UNNotificationRequest] = []
    private(set) var events: [String] = []
    private var firstAddContinuation: CheckedContinuation<Void, Never>?
    private var firstAddStarted: CheckedContinuation<Void, Never>?
    private var shouldPauseFirstAdd: Bool

    init(shouldPauseFirstAdd: Bool = true) {
        self.shouldPauseFirstAdd = shouldPauseFirstAdd
    }

    func seedPendingRequests(identifiers: [String]) {
        pending = identifiers.map { identifier in
            UNNotificationRequest(
                identifier: identifier,
                content: UNMutableNotificationContent(),
                trigger: nil
            )
        }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pending
    }

    func add(_ request: UNNotificationRequest) async throws {
        if shouldPauseFirstAdd {
            shouldPauseFirstAdd = false
            firstAddStarted?.resume()
            firstAddStarted = nil
            await withCheckedContinuation { continuation in
                firstAddContinuation = continuation
            }
        }
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
        events.append("add:\(request.content.body)")
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pending.removeAll { identifiers.contains($0.identifier) }
        events.append("remove:\(identifiers.count)")
    }

    func waitForFirstAdd() async {
        if firstAddContinuation != nil { return }
        await withCheckedContinuation { continuation in
            firstAddStarted = continuation
        }
    }

    func releaseFirstAdd() {
        firstAddContinuation?.resume()
        firstAddContinuation = nil
    }
}
