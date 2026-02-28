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
        // Pre-compute day offsets from reference for O(1) lookup
        let refDay = calendar.startOfDay(for: referenceDate)
        let uniqueDayOffsets = Set(completedDates.map { dayOffset(from: refDay, to: $0, calendar: calendar) })

        // Walk backwards from offset 0 (today)
        var streak = 0
        var offset = 0

        while uniqueDayOffsets.contains(offset) {
            streak += 1
            offset -= 1
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

        // Pre-compute all completed day offsets from reference (single Calendar batch)
        let refDay = calendar.startOfDay(for: referenceDate)
        let uniqueDayOffsets = Set(completedDates.map { dayOffset(from: refDay, to: $0, calendar: calendar) })

        // Find start of current week as day offset
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return 0
        }
        let refWeekStartOffset = dayOffset(from: refDay, to: weekInterval.start, calendar: calendar)

        var streak = 0
        let maxWeeks = 52

        for weekIndex in 0..<maxWeeks {
            let weekStartOffset = refWeekStartOffset - (weekIndex * 7)

            // Count completed days in this week using pre-computed offsets (no Calendar calls)
            var daysInWeek = 0
            for dayInWeek in 0..<7 {
                if uniqueDayOffsets.contains(weekStartOffset + dayInWeek) {
                    daysInWeek += 1
                }
            }

            if daysInWeek >= targetDays {
                streak += 1
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Helpers

    /// Day offset from `reference` to `date` (negative = past, positive = future).
    /// Uses Calendar only once per call, enabling batch pre-computation.
    private static func dayOffset(from reference: Date, to date: Date, calendar: Calendar) -> Int {
        let target = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: reference, to: target).day ?? 0
    }
}
