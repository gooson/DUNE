import Foundation
import Observation

/// ViewModel for the Consistency detail view.
@Observable
@MainActor
final class ConsistencyDetailViewModel {
    var workoutStreak: WorkoutStreak?
    var streakHistory: [StreakPeriod] = []
    var workoutDates: Set<DateComponents> = []
    var isLoading = false

    private let library: ExerciseLibraryQuerying

    init(library: ExerciseLibraryQuerying = ExerciseLibraryService.shared) {
        self.library = library
    }

    /// Loads streak and calendar data from exercise records.
    func loadData(from exerciseRecords: [ExerciseRecord]) {
        isLoading = true

        let workouts: [WorkoutStreakService.WorkoutDay] = exerciseRecords.map { record in
            WorkoutStreakService.WorkoutDay(
                date: record.date,
                durationMinutes: record.duration > 0 ? record.duration / 60.0 : 0
            )
        }

        workoutStreak = WorkoutStreakService.calculate(from: workouts)
        streakHistory = WorkoutStreakService.extractStreakHistory(from: workouts)

        let calendar = Calendar.current
        workoutDates = Set(
            workouts
                .filter { $0.durationMinutes >= 20 }
                .map { calendar.dateComponents([.year, .month, .day], from: $0.date) }
        )

        isLoading = false
    }

    /// Returns dates for the current month grid.
    func calendarDays(for month: Date = Date()) -> [Date] {
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

    /// Checks if a given date had a workout.
    func hasWorkout(on date: Date) -> Bool {
        let dc = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return workoutDates.contains(dc)
    }

    /// First weekday offset for month grid alignment (0 = Sunday).
    func firstWeekdayOffset(for month: Date = Date()) -> Int {
        let calendar = Calendar.current
        guard let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else { return 0 }
        // weekday: 1=Sunday...7=Saturday
        return calendar.component(.weekday, from: firstDay) - 1
    }
}
