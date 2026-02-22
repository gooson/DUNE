import Foundation
import Testing
@testable import Dailve

@Suite("WorkoutStreakService")
struct WorkoutStreakServiceTests {
    let calendar = Calendar.current

    private func workoutDay(daysAgo: Int, minutes: Double = 30) -> WorkoutStreakService.WorkoutDay {
        .init(
            date: calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
            durationMinutes: minutes
        )
    }

    // MARK: - Empty / No Data

    @Test("Empty workouts returns zero streak")
    func emptyWorkouts() {
        let result = WorkoutStreakService.calculate(from: [])
        #expect(result.currentStreak == 0)
        #expect(result.bestStreak == 0)
        #expect(result.monthlyCount == 0)
    }

    // MARK: - Current Streak

    @Test("Single workout today gives streak of 1")
    func singleToday() {
        let result = WorkoutStreakService.calculate(from: [workoutDay(daysAgo: 0)])
        #expect(result.currentStreak == 1)
    }

    @Test("Single workout yesterday gives streak of 1")
    func singleYesterday() {
        let result = WorkoutStreakService.calculate(from: [workoutDay(daysAgo: 1)])
        #expect(result.currentStreak == 1)
    }

    @Test("Workout 2 days ago breaks current streak")
    func twoDaysAgoNoStreak() {
        let result = WorkoutStreakService.calculate(from: [workoutDay(daysAgo: 2)])
        #expect(result.currentStreak == 0)
    }

    @Test("Consecutive days form streak")
    func consecutiveDays() {
        let days = [
            workoutDay(daysAgo: 0),
            workoutDay(daysAgo: 1),
            workoutDay(daysAgo: 2),
        ]
        let result = WorkoutStreakService.calculate(from: days)
        #expect(result.currentStreak == 3)
    }

    @Test("Gap breaks streak")
    func gapBreaksStreak() {
        let days = [
            workoutDay(daysAgo: 0),
            workoutDay(daysAgo: 1),
            // gap at 2
            workoutDay(daysAgo: 3),
            workoutDay(daysAgo: 4),
        ]
        let result = WorkoutStreakService.calculate(from: days)
        #expect(result.currentStreak == 2)
    }

    // MARK: - Best Streak

    @Test("Best streak captures historical max")
    func bestStreakHistorical() {
        let days = [
            workoutDay(daysAgo: 0),  // current: 1
            // gap
            workoutDay(daysAgo: 10),
            workoutDay(daysAgo: 11),
            workoutDay(daysAgo: 12),
            workoutDay(daysAgo: 13),  // historical: 4
        ]
        let result = WorkoutStreakService.calculate(from: days)
        #expect(result.currentStreak == 1)
        #expect(result.bestStreak >= 4)
    }

    @Test("Best streak is at least current streak")
    func bestStreakAtLeastCurrent() {
        let days = (0..<5).map { workoutDay(daysAgo: $0) }
        let result = WorkoutStreakService.calculate(from: days)
        #expect(result.bestStreak >= result.currentStreak)
    }

    // MARK: - Minimum Minutes Filter

    @Test("Short workouts filtered by minimumMinutes")
    func minimumMinutesFilter() {
        let days = [
            workoutDay(daysAgo: 0, minutes: 10),  // Too short
            workoutDay(daysAgo: 1, minutes: 25),
            workoutDay(daysAgo: 2, minutes: 30),
        ]
        let result = WorkoutStreakService.calculate(from: days, minimumMinutes: 20)
        // Day 0 filtered → streak starts from day 1
        #expect(result.currentStreak == 2)
    }

    @Test("Zero minimumMinutes accepts all workouts")
    func zeroMinimumAcceptsAll() {
        let days = [workoutDay(daysAgo: 0, minutes: 1)]
        let result = WorkoutStreakService.calculate(from: days, minimumMinutes: 0)
        #expect(result.currentStreak == 1)
    }

    // MARK: - Monthly Count

    @Test("Monthly count only includes current month")
    func monthlyCountCurrentMonth() {
        let today = Date()
        let thisMonth = [
            workoutDay(daysAgo: 0),
            workoutDay(daysAgo: 1),
        ]
        // Last month workout
        let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: today) ?? today
        let lastMonth = WorkoutStreakService.WorkoutDay(date: lastMonthDate, durationMinutes: 30)

        let result = WorkoutStreakService.calculate(from: thisMonth + [lastMonth], referenceDate: today)
        #expect(result.monthlyCount == 2)
    }

    // MARK: - Monthly Percentage

    @Test("Monthly percentage capped at 1.0")
    func monthlyPercentageCapped() {
        let streak = WorkoutStreak(currentStreak: 0, bestStreak: 0, monthlyCount: 20, monthlyGoal: 16)
        #expect(streak.monthlyPercentage == 1.0)
    }

    @Test("Monthly percentage correct calculation")
    func monthlyPercentageCalc() {
        let streak = WorkoutStreak(currentStreak: 0, bestStreak: 0, monthlyCount: 8, monthlyGoal: 16)
        #expect(streak.monthlyPercentage == 0.5)
    }

    // MARK: - Duplicate Days

    @Test("Multiple workouts on same day count as one day")
    func duplicateDaysSingleCount() {
        let days = [
            workoutDay(daysAgo: 0),
            workoutDay(daysAgo: 0),  // Same day
            workoutDay(daysAgo: 1),
        ]
        let result = WorkoutStreakService.calculate(from: days)
        #expect(result.currentStreak == 2)
    }
}
