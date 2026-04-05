import Testing
import Foundation
@testable import DUNE

@Suite("HabitStreakService Tests")
struct HabitStreakServiceTests {
    private let habitID = UUID()
    private let calendar = Calendar.current

    private func makeLog(daysAgo: Int, memo: String? = nil) -> HabitLogSnapshot {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        return HabitLogSnapshot(habitID: habitID, date: date, value: 1.0, memo: memo)
    }

    // MARK: - Longest Streak

    @Test func emptyLogs() {
        let result = HabitStreakService.longestStreak(logs: [], for: habitID)
        #expect(result == 0)
    }

    @Test func singleLog() {
        let logs = [makeLog(daysAgo: 0)]
        let result = HabitStreakService.longestStreak(logs: logs, for: habitID)
        #expect(result == 1)
    }

    @Test func consecutiveThreeDays() {
        let logs = [
            makeLog(daysAgo: 0),
            makeLog(daysAgo: 1),
            makeLog(daysAgo: 2)
        ]
        let result = HabitStreakService.longestStreak(logs: logs, for: habitID)
        #expect(result == 3)
    }

    @Test func gapBreaksStreak() {
        // Days: 0, 1, 2, [gap], 5, 6 → longest streak = 3
        let logs = [
            makeLog(daysAgo: 0),
            makeLog(daysAgo: 1),
            makeLog(daysAgo: 2),
            makeLog(daysAgo: 5),
            makeLog(daysAgo: 6)
        ]
        let result = HabitStreakService.longestStreak(logs: logs, for: habitID)
        #expect(result == 3)
    }

    @Test func longestStreakNotMostRecent() {
        // Days: 0, [gap], 3, 4, 5, 6, 7 → longest streak = 5
        let logs = [
            makeLog(daysAgo: 0),
            makeLog(daysAgo: 3),
            makeLog(daysAgo: 4),
            makeLog(daysAgo: 5),
            makeLog(daysAgo: 6),
            makeLog(daysAgo: 7)
        ]
        let result = HabitStreakService.longestStreak(logs: logs, for: habitID)
        #expect(result == 5)
    }

    @Test func skipAndSnoozeExcluded() {
        let logs = [
            makeLog(daysAgo: 0),
            makeLog(daysAgo: 1, memo: "[dune-life-cycle-skip]"),
            makeLog(daysAgo: 2),
            makeLog(daysAgo: 3, memo: "[dune-life-cycle-snooze]"),
            makeLog(daysAgo: 4)
        ]
        // After filtering: days 0, 2, 4 → no consecutive → longest = 1
        let result = HabitStreakService.longestStreak(logs: logs, for: habitID)
        #expect(result == 1)
    }

    @Test func filtersToCorrectHabit() {
        let otherID = UUID()
        let logs = [
            makeLog(daysAgo: 0),
            HabitLogSnapshot(habitID: otherID, date: Date(), value: 1.0, memo: nil)
        ]
        let result = HabitStreakService.longestStreak(logs: logs, for: habitID)
        #expect(result == 1)

        let otherResult = HabitStreakService.longestStreak(logs: logs, for: otherID)
        #expect(otherResult == 1)
    }

    // MARK: - Total Completions

    @Test func totalCompletionsEmpty() {
        let result = HabitStreakService.totalCompletions(logs: [], for: habitID)
        #expect(result == 0)
    }

    @Test func totalCompletionsExcludesSkipSnooze() {
        let logs = [
            makeLog(daysAgo: 0),
            makeLog(daysAgo: 1),
            makeLog(daysAgo: 2, memo: "[dune-life-cycle-skip]"),
            makeLog(daysAgo: 3, memo: "[dune-life-cycle-snooze]"),
            makeLog(daysAgo: 4)
        ]
        let result = HabitStreakService.totalCompletions(logs: logs, for: habitID)
        #expect(result == 3)
    }

    @Test func totalCompletionsFiltersHabit() {
        let otherID = UUID()
        let logs = [
            makeLog(daysAgo: 0),
            makeLog(daysAgo: 1),
            HabitLogSnapshot(habitID: otherID, date: Date(), value: 1.0, memo: nil)
        ]
        let result = HabitStreakService.totalCompletions(logs: logs, for: habitID)
        #expect(result == 2)
    }
}
