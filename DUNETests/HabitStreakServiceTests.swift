import Foundation
import Testing
@testable import DUNE

@Suite("HabitStreakService")
struct HabitStreakServiceTests {

    // MARK: - Daily Streak

    @Test("empty dates returns 0 streak")
    func emptyStreak() {
        let result = HabitStreakService.calculateStreak(
            completedDates: [],
            frequency: .daily,
            referenceDate: Date()
        )
        #expect(result == 0)
    }

    @Test("consecutive 3 days returns streak 3")
    func threeDayStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = [
            today,
            calendar.date(byAdding: .day, value: -1, to: today)!,
            calendar.date(byAdding: .day, value: -2, to: today)!
        ]
        let result = HabitStreakService.calculateStreak(
            completedDates: dates,
            frequency: .daily,
            referenceDate: today
        )
        #expect(result == 3)
    }

    @Test("gap breaks streak — only today counts")
    func gapBreaksStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = [
            today,
            // skip yesterday
            calendar.date(byAdding: .day, value: -2, to: today)!,
            calendar.date(byAdding: .day, value: -3, to: today)!
        ]
        let result = HabitStreakService.calculateStreak(
            completedDates: dates,
            frequency: .daily,
            referenceDate: today
        )
        #expect(result == 1)
    }

    @Test("duplicate dates are deduped")
    func duplicateDates() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = [today, today, today]
        let result = HabitStreakService.calculateStreak(
            completedDates: dates,
            frequency: .daily,
            referenceDate: today
        )
        #expect(result == 1)
    }

    @Test("no today entry returns 0 streak")
    func noTodayEntry() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = [
            calendar.date(byAdding: .day, value: -1, to: today)!,
            calendar.date(byAdding: .day, value: -2, to: today)!
        ]
        let result = HabitStreakService.calculateStreak(
            completedDates: dates,
            frequency: .daily,
            referenceDate: today
        )
        #expect(result == 0)
    }

    @Test("past date retroactive check contributes to streak")
    func retroactiveCheck() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // All 5 days completed including today
        let dates = (0..<5).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        let result = HabitStreakService.calculateStreak(
            completedDates: dates,
            frequency: .daily,
            referenceDate: today
        )
        #expect(result == 5)
    }

    // MARK: - Weekly Streak

    @Test("weekly target met this week returns streak 1")
    func weeklyStreakOneWeek() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return }
        // Target: 3 days per week. Complete 3 days this week.
        let dates = (0..<3).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        let result = HabitStreakService.calculateStreak(
            completedDates: dates,
            frequency: .weekly(targetDays: 3),
            referenceDate: today
        )
        #expect(result >= 1)
    }

    @Test("weekly target not met returns streak 0")
    func weeklyStreakNotMet() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return }
        // Target: 5 days per week. Complete only 2.
        let dates = (0..<2).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        let result = HabitStreakService.calculateStreak(
            completedDates: dates,
            frequency: .weekly(targetDays: 5),
            referenceDate: today
        )
        #expect(result == 0)
    }

    @Test("weekly target 0 returns streak 0")
    func weeklyTargetZero() {
        let result = HabitStreakService.calculateStreak(
            completedDates: [Date()],
            frequency: .weekly(targetDays: 0),
            referenceDate: Date()
        )
        #expect(result == 0)
    }
}
