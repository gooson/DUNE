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
    private(set) var previousWeeks: [WorkoutSummary] = []
    private var loadedHistoryWeek: Date?
    private var historyRequestID = 0
    private(set) var revision = 0
    private var appliedRequestID = 0
    private var requestID = 0

    init(service: any WorkoutQuerying = WorkoutQueryService(manager: .shared)) {
        self.service = service
    }

    @discardableResult
    func refresh(now: Date = Date()) async -> Bool {
        requestID += 1
        let request = requestID
        let start = LifeAutoAchievementService.weekStart(containing: now)
        do {
            let results = try await service.fetchWorkouts(start: start, end: now)
            guard !Task.isCancelled else { return false }
            guard request > appliedRequestID else { return true }
            appliedRequestID = request
            workouts = Self.eligible(results).sorted { $0.date > $1.date }
            revision += 1
            return true
        } catch {
            AppLogger.healthKit.error("Life workout refresh failed: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }

    /// The achievement board evaluates at most 260 consecutive weeks.
    func loadPreviousWeeks(now: Date = Date(), force: Bool = false) async {
        let week = LifeAutoAchievementService.weekStart(containing: now)
        guard force || loadedHistoryWeek != week,
              let start = Calendar.current.date(byAdding: .weekOfYear, value: -259, to: week) else { return }
        historyRequestID += 1
        let request = historyRequestID
        do {
            let history = try await service.fetchWorkouts(start: start, end: week)
            guard !Task.isCancelled, request == historyRequestID else { return }
            previousWeeks = Self.eligible(history.filter { $0.date < week }).sorted { $0.date > $1.date }
            loadedHistoryWeek = week
            revision += 1
        } catch {
            AppLogger.healthKit.error("Life workout history failed: \(error.localizedDescription, privacy: .private)")
        }
    }

    var latestDate: Date? {
        workouts.first?.date ?? previousWeeks.first?.date
    }

    static func eligible(_ workouts: [WorkoutSummary]) -> [WorkoutSummary] {
        let deleted = DeletedWorkoutTombstoneStore.shared.tombstonedIDs
        return workouts.filter { $0.duration.isFinite && $0.duration > 0 && !deleted.contains($0.id) }
    }

    func hasWorkout(on date: Date) -> Bool {
        workouts.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    /// HealthKit can wake the app before any SwiftUI view is mounted.
    func refreshReminders(in context: ModelContext, scheduler: HabitReminderScheduler = .shared) async {
        // A locked store can fail a background read. Preserve the pending schedule
        // until HealthKit returns a workout snapshot.
        guard await refresh() else { return }
        let now = Date()
        do {
            let habits = try context.fetch(FetchDescriptor<HabitDefinition>(predicate: #Predicate {
                !$0.isArchived && $0.isAutoLinked && $0.autoLinkSourceRaw == "exercise"
            }))
            guard !habits.isEmpty else { return }
            if habits.contains(where: { $0.frequencyTypeRaw == "interval" }) {
                await loadPreviousWeeks(now: now)
            }
            var descriptor = FetchDescriptor<ExerciseRecord>(predicate: #Predicate { $0.date <= now },
                                                              sortBy: [SortDescriptor(\.date, order: .reverse)])
            descriptor.fetchLimit = 1
            let latestLocal = try context.fetch(descriptor).first?.date
            let latest = [latestDate, latestLocal].compactMap { $0 }.max()
            let hasExercise = latest.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false
            let model = LifeViewModel()
            model.setWorkoutDates(latest.map { [$0] } ?? [])
            for habit in habits {
                model.refreshReminderSchedule(for: habit, referenceDate: now, todayExerciseExists: hasExercise, scheduler: scheduler)
            }
            await scheduler.waitForPendingOperations()
        } catch {
            AppLogger.notification.error("Exercise habit reminder refresh failed: \(error.localizedDescription, privacy: .private)")
        }
    }
}
