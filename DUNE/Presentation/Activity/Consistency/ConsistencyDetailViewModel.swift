import Foundation
import Observation
import OSLog

/// ViewModel for the Consistency detail view.
@Observable
@MainActor
final class ConsistencyDetailViewModel {
    private enum Scheduling {
        static let healthKitHistoryDays = 3650
    }

    var workoutStreak: WorkoutStreak?
    var streakHistory: [StreakPeriod] = []
    var workoutDates: Set<DateComponents> = []
    var cachedCalendarDays: [Date] = []
    var cachedFirstWeekdayOffset: Int = 0
    var isLoading = false
    private let workoutService: WorkoutQuerying

    init(workoutService: WorkoutQuerying? = nil, healthKitManager: HealthKitManager = .shared) {
        self.workoutService = workoutService ?? WorkoutQueryService(manager: healthKitManager)
    }

    /// Loads streak and calendar data from exercise records.
    func loadData(from exerciseRecords: [ExerciseRecord]) async {
        isLoading = true
        defer { isLoading = false }

        let manualWorkouts: [WorkoutStreakService.WorkoutDay] = exerciseRecords.map { record in
            WorkoutStreakService.WorkoutDay(
                date: record.date,
                durationMinutes: record.duration > 0 ? record.duration / 60.0 : 0
            )
        }
        let healthKitWorkouts = await fetchHealthKitWorkouts()
        guard !Task.isCancelled else { return }

        let workouts = manualWorkouts + healthKitWorkouts

        workoutStreak = WorkoutStreakService.calculate(from: workouts)
        streakHistory = WorkoutStreakService.extractStreakHistory(from: workouts)

        let calendar = Calendar.current
        workoutDates = Set(
            workouts
                .filter { $0.durationMinutes >= 20 }
                .map { calendar.dateComponents([.year, .month, .day], from: $0.date) }
        )

        // Cache calendar grid data to avoid recomputation on each render
        cachedCalendarDays = computeCalendarDays()
        cachedFirstWeekdayOffset = computeFirstWeekdayOffset()
    }

    /// Checks if a given date had a workout.
    func hasWorkout(on date: Date) -> Bool {
        let dc = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return workoutDates.contains(dc)
    }

    // MARK: - Private

    private func computeCalendarDays(for month: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }

        var days: [Date] = []
        var current = monthInterval.start
        while current < monthInterval.end {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return days
    }

    private func computeFirstWeekdayOffset(for month: Date = Date()) -> Int {
        let calendar = Calendar.current
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return 0 }
        // weekday: 1=Sunday...7=Saturday
        return calendar.component(.weekday, from: firstDay) - 1
    }

    private func fetchHealthKitWorkouts() async -> [WorkoutStreakService.WorkoutDay] {
        do {
            let workouts = try await workoutService.fetchWorkouts(days: Scheduling.healthKitHistoryDays)
            return workouts.map { workout in
                WorkoutStreakService.WorkoutDay(
                    date: workout.date,
                    durationMinutes: workout.duration / 60.0
                )
            }
        } catch {
            AppLogger.ui.error("Consistency workouts fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}
