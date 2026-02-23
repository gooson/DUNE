import Foundation
import Testing
@testable import Dailve

@Suite("WorkoutStreakService.extractStreakHistory")
struct StreakHistoryTests {

    private let calendar = Calendar.current

    private func day(_ offset: Int, from base: Date = Date()) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: base) ?? base)
    }

    private func entry(_ offset: Int, minutes: Double = 30) -> WorkoutStreakService.WorkoutDay {
        WorkoutStreakService.WorkoutDay(date: day(offset), durationMinutes: minutes)
    }

    @Test("Empty input returns empty")
    func emptyInput() {
        let result = WorkoutStreakService.extractStreakHistory(from: [])
        #expect(result.isEmpty)
    }

    @Test("Single workout day returns single streak of 1 day")
    func singleDay() {
        let result = WorkoutStreakService.extractStreakHistory(from: [entry(-3)])
        #expect(result.count == 1)
        #expect(result[0].days == 1)
    }

    @Test("Three consecutive days returns single streak of 3 days")
    func consecutiveThreeDays() {
        let entries = [entry(-3), entry(-2), entry(-1)]
        let result = WorkoutStreakService.extractStreakHistory(from: entries)
        #expect(result.count == 1)
        #expect(result[0].days == 3)
    }

    @Test("Gap creates separate streaks")
    func gapCreatesSeparateStreaks() {
        // Day -5, -4, (gap), -2, -1
        let entries = [entry(-5), entry(-4), entry(-2), entry(-1)]
        let result = WorkoutStreakService.extractStreakHistory(from: entries)
        #expect(result.count == 2)
        // Most recent first
        #expect(result[0].days == 2) // days -2, -1
        #expect(result[1].days == 2) // days -5, -4
    }

    @Test("Duplicate dates are deduplicated")
    func duplicateDates() {
        // Two workouts on same day
        let entries = [entry(-2), entry(-2, minutes: 45), entry(-1)]
        let result = WorkoutStreakService.extractStreakHistory(from: entries)
        #expect(result.count == 1)
        #expect(result[0].days == 2)
    }

    @Test("Short workouts below minimum are filtered out")
    func minimumDurationFilter() {
        // Day -3 (10min < 20min minimum) creates a gap
        let entries = [entry(-4), entry(-3, minutes: 10), entry(-2), entry(-1)]
        let result = WorkoutStreakService.extractStreakHistory(from: entries)
        #expect(result.count == 2)
        #expect(result[0].days == 2) // -2, -1
        #expect(result[1].days == 1) // -4
    }

    @Test("All below minimum returns empty")
    func allBelowMinimum() {
        let entries = [entry(-3, minutes: 5), entry(-2, minutes: 10)]
        let result = WorkoutStreakService.extractStreakHistory(from: entries)
        #expect(result.isEmpty)
    }

    @Test("Results sorted by startDate descending")
    func sortOrder() {
        let entries = [entry(-10), entry(-5), entry(-4), entry(-1)]
        let result = WorkoutStreakService.extractStreakHistory(from: entries)
        // Should be: [-5,-4], [-1], [-10] by startDate desc
        #expect(result.count == 3)
        #expect(result[0].startDate > result[1].startDate)
        #expect(result[1].startDate > result[2].startDate)
    }
}
