import Foundation
import Observation
import SwiftData

/// Health workouts are shared by Life and the reminder scheduler.
@Observable
@MainActor
final class LifeHealthKitWorkouts {
    static let shared = LifeHealthKitWorkouts()
    private let service: any WorkoutQuerying
    private(set) var workouts: [WorkoutSummary] = []
    private(set) var historyGeneration = 0
    private(set) var revision = 0
    private var loadedWeek: Date?
    private var pendingWeek: Date?
    private var pendingRead: Task<Bool, Never>?

    init(service: any WorkoutQuerying = WorkoutQueryService(manager: .shared)) {
        self.service = service
    }

    func invalidateWorkoutHistory(discardCached: Bool = false) {
        pendingRead?.cancel()
        pendingRead = nil
        loadedWeek = nil
        historyGeneration += 1
        if discardCached {
            workouts = []
            revision += 1
            reminderDateLookup?.cancel()
            reminderDateLookup = nil
            reminderLookupID += 1
            reminderDateResult = .pending
            reminderAccessGeneration += 1
        }
    }

    /// Only Life requests the full streak window. Reopening the board within the
    /// same week refreshes recent workouts unless HealthKit reported a change.
    @discardableResult
    func refresh(now: Date = Date()) async -> Bool {
        let week = LifeAutoAchievementService.weekStart(containing: now)
        if let pendingRead, pendingWeek == week { return await pendingRead.value }
        pendingRead?.cancel()
        let fullRead = loadedWeek != week
        guard let start = fullRead ? Calendar.current.date(byAdding: .weekOfYear, value: -259, to: week) : week else {
            return false
        }
        pendingWeek = week
        let task = Task { @MainActor in
            do {
                let results = try await service.fetchWorkouts(start: start, end: now)
                try Task.checkCancellation()
                let earlier = fullRead ? [] : workouts.filter { $0.date < week }
                workouts = earlier + Self.eligible(results)
                loadedWeek = week
                revision += 1
                pendingRead = nil
                return true
            } catch {
                if !Task.isCancelled {
                    pendingRead = nil
                    AppLogger.healthKit.error("Life workout refresh failed: \(error.localizedDescription, privacy: .private)")
                }
                return false
            }
        }
        pendingRead = task
        return await task.value
    }

    static func eligible(_ workouts: [WorkoutSummary]) -> [WorkoutSummary] {
        let deleted = DeletedWorkoutTombstoneStore.shared.tombstonedIDs
        return workouts.filter { $0.duration.isFinite && $0.duration > 0 && !deleted.contains($0.id) }
    }

    func hasWorkout(on date: Date) -> Bool {
        workouts.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var isReminderHealthDataAvailable: Bool { service.isReminderHealthDataAvailable }

    private(set) var reminderAccessGeneration = 0
    private var reminderDateResult: HabitReminderSyncState.WorkoutSource = .pending
    private var reminderLookupTombstones: Set<String> = []
    private var reminderDateLookup: Task<Date?, Error>?
    private var reminderLookupID = 0

    var reminderLookupIncludesCurrentTombstones: Bool {
        reminderLookupTombstones == DeletedWorkoutTombstoneStore.shared.tombstonedIDs
    }

    var reminderHealthWorkoutSource: HabitReminderSyncState.WorkoutSource {
        reminderLookupIncludesCurrentTombstones ? reminderDateResult : .pending
    }

    @discardableResult
    func refreshReminderHealthWorkoutDate(before now: Date, replacingLookup: Bool = false) async -> Bool {
        let deleted = DeletedWorkoutTombstoneStore.shared.tombstonedIDs
        if let reminderDateLookup, !replacingLookup, reminderLookupTombstones == deleted {
            let request = reminderLookupID
            let result = await reminderDateLookup.result
            guard request == reminderLookupID, case .success = result else { return false }
            return true
        }

        reminderDateLookup?.cancel()
        reminderLookupID += 1
        let request = reminderLookupID
        reminderLookupTombstones = deleted
        reminderDateResult = .pending
        let lookup = Task { [service] in
            try await service.latestWorkoutDate(before: now, excludingIDs: deleted)
        }
        reminderDateLookup = lookup
        let result = await lookup.result
        guard request == reminderLookupID else { return false }
        reminderDateLookup = nil
        switch result {
        case .success(let date):
            reminderDateResult = .resolved(date)
            return true
        case .failure(let error):
            AppLogger.healthKit.error("Workout date query for reminders failed: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }

    static func latestLocalWorkoutDate(
        in context: ModelContext,
        before now: Date,
        excludingIDs: Set<String> = DeletedWorkoutTombstoneStore.shared.tombstonedIDs
    ) throws -> Date? {
        var descriptor = FetchDescriptor<ExerciseRecord>(
            predicate: #Predicate { $0.date <= now },
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = excludingIDs.isEmpty ? 1 : 32
        while true {
            let records = try context.fetch(descriptor)
            if let latest = records.first(where: { record in
                record.healthKitWorkoutID.map(excludingIDs.contains) != true
            }) {
                return latest.date
            }
            guard records.count == descriptor.fetchLimit else { return nil }
            descriptor.fetchOffset = (descriptor.fetchOffset ?? 0) + records.count
        }
    }

    /// HealthKit can wake the app before any SwiftUI view is mounted.
    func refreshReminders(in context: ModelContext, scheduler: HabitReminderScheduler = .shared) async {
        invalidateWorkoutHistory()
        do {
            let habitDescriptor = FetchDescriptor<HabitDefinition>(predicate: #Predicate {
                !$0.isArchived && $0.isAutoLinked && $0.autoLinkSourceRaw == "exercise"
            })
            var oneHabit = habitDescriptor
            oneHabit.fetchLimit = 1
            guard try !context.fetch(oneHabit).isEmpty else { return }
            // A locked store can fail a background read. Keep existing requests until a retry succeeds.
            if isReminderHealthDataAvailable {
                let accessGeneration = reminderAccessGeneration
                var didRead = await refreshReminderHealthWorkoutDate(before: Date(), replacingLookup: true)
                // Backgrounding can invalidate a lookup already started by this delivery.
                if reminderAccessGeneration != accessGeneration, !Task.isCancelled {
                    didRead = await refreshReminderHealthWorkoutDate(before: Date())
                }
                guard didRead, case .resolved = reminderHealthWorkoutSource else { return }
            }
            guard !Task.isCancelled else { return }
            let now = Date()
            let localDate = try Self.latestLocalWorkoutDate(in: context, before: now)
            let latest = Self.combinedReminderDate(
                local: localDate,
                health: isReminderHealthDataAvailable ? reminderHealthWorkoutSource : .resolved(nil)
            )
            guard case .resolved(let latestDate) = latest else { return }
            let hasExercise = latestDate.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
            let model = LifeViewModel()
            model.setWorkoutDates(latestDate.map { [$0] } ?? [])
            for habit in try context.fetch(habitDescriptor) {
                model.refreshReminderSchedule(for: habit, referenceDate: now, todayExerciseExists: hasExercise, scheduler: scheduler)
            }
            await scheduler.waitForPendingOperations()
        } catch {
            AppLogger.notification.error("Exercise habit reminder refresh failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    static func combinedReminderDate(
        local: Date?,
        health: HabitReminderSyncState.WorkoutSource
    ) -> HabitReminderSyncState.WorkoutSource {
        guard case .resolved(let healthDate) = health else { return .pending }
        return .resolved([local, healthDate].compactMap { $0 }.max())
    }
}
