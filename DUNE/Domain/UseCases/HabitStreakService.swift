import Foundation

enum HabitStreakService {
    /// Calculate consecutive completion streak from reference date backwards.
    ///
    /// - Parameters:
    ///   - completedDates: Dates when habit was completed (any order, duplicates OK).
    ///   - frequency: Daily or weekly target.
    ///   - referenceDate: Typically today. Streak counts backwards from this date.
    /// - Returns: Number of consecutive periods (days for daily, weeks for weekly).
    static func calculateStreak(
        completedDates: [Date],
        frequency: HabitFrequency,
        referenceDate: Date = Date()
    ) -> Int {
        guard !completedDates.isEmpty else { return 0 }

        let calendar = Calendar.current

        switch frequency {
        case .daily:
            return calculateDailyStreak(
                completedDates: completedDates,
                referenceDate: referenceDate,
                calendar: calendar
            )
        case .weekly(let targetDays):
            return calculateWeeklyStreak(
                completedDates: completedDates,
                targetDays: targetDays,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
    }

    // MARK: - Daily Streak

    private static func calculateDailyStreak(
        completedDates: [Date],
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        // Dedup to unique calendar days
        let uniqueDays = Set(completedDates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: referenceDate)

        // Start from today and walk backwards
        var streak = 0
        var checkDate = today

        while uniqueDays.contains(checkDate) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }

        return streak
    }

    // MARK: - Weekly Streak

    private static func calculateWeeklyStreak(
        completedDates: [Date],
        targetDays: Int,
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        guard targetDays > 0 else { return 0 }

        let uniqueDays = Set(completedDates.map { calendar.startOfDay(for: $0) })

        // Find start of current week
        guard var weekStart = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start else {
            return 0
        }

        var streak = 0
        // Check up to 52 weeks back
        let maxWeeks = 52

        for _ in 0..<maxWeeks {
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }

            // Count completed days in this week
            var daysInWeek = 0
            var day = weekStart
            while day < weekEnd {
                if uniqueDays.contains(day) {
                    daysInWeek += 1
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }

            if daysInWeek >= targetDays {
                streak += 1
            } else {
                break
            }

            // Move to previous week
            guard let prevWeek = calendar.date(byAdding: .day, value: -7, to: weekStart) else { break }
            weekStart = prevWeek
        }

        return streak
    }
}
