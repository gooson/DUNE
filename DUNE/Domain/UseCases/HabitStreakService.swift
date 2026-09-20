import Foundation

enum HabitStreakService {
    private static let skipMemoMarker = "[dune-life-cycle-skip]"
    private static let snoozeMemoMarker = "[dune-life-cycle-snooze]"

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
        case .interval(let days):
            return calculateIntervalStreak(
                completedDates: completedDates,
                intervalDays: days,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
    }

    // MARK: - Longest Streak (Snapshot-based)

    /// Calculates the longest consecutive daily streak for a habit from log snapshots.
    static func longestStreak(logs: [HabitLogSnapshot], for habitID: UUID, goalValue: Double, calendar: Calendar = .current) -> Int {
        let completionDates = completedDates(logs: logs, for: habitID, goalValue: goalValue, calendar: calendar)

        let uniqueDates = Set(completionDates).sorted()
        guard !uniqueDates.isEmpty else { return 0 }

        var maxStreak = 1
        var currentStreak = 1

        for i in 1..<uniqueDates.count {
            let daysBetween = calendar.dateComponents([.day], from: uniqueDates[i - 1], to: uniqueDates[i]).day ?? 0
            if daysBetween == 1 {
                currentStreak += 1
                maxStreak = Swift.max(maxStreak, currentStreak)
            } else if daysBetween > 1 {
                currentStreak = 1
            }
            // daysBetween == 0 means duplicate date after startOfDay normalization — skip
        }

        return maxStreak
    }

    /// Count completed days, not individual increments.
    static func totalCompletions(logs: [HabitLogSnapshot], for habitID: UUID, goalValue: Double) -> Int {
        completedDates(logs: logs, for: habitID, goalValue: goalValue).count
    }

    /// A day is complete only when its valid increments reach the habit goal.
    static func completedDates(
        logs: [HabitLogSnapshot],
        for habitID: UUID,
        goalValue: Double,
        calendar: Calendar = .current
    ) -> [Date] {
        guard goalValue > 0, goalValue.isFinite else { return [] }
        var totals: [Date: Double] = [:]
        for log in logs where log.habitID == habitID {
            guard !isSkipOrSnooze(log), log.value > 0, log.value.isFinite else { continue }
            let day = calendar.startOfDay(for: log.date)
            // Clamp to the goal to avoid overflow when summing imported values.
            let total = totals[day, default: 0]
            totals[day] = total + min(log.value, goalValue - total)
        }
        return totals.filter { $0.value >= goalValue }.map(\.key).sorted()
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

    // MARK: - Interval Streak

    private static func calculateIntervalStreak(
        completedDates: [Date],
        intervalDays: Int,
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        guard intervalDays > 0 else { return 0 }

        let referenceDay = calendar.startOfDay(for: referenceDate)
        let uniqueDays = Set(completedDates.map { calendar.startOfDay(for: $0) })
        let sorted = uniqueDays.sorted(by: >)
        guard let latest = sorted.first else { return 0 }

        let latestOffset = dayOffset(from: referenceDay, to: latest, calendar: calendar)
        if latestOffset > 0 { return 0 }

        var streak = 1
        var previous = latest

        for date in sorted.dropFirst() {
            let gap = calendar.dateComponents([.day], from: date, to: previous).day ?? .max
            if gap <= intervalDays {
                streak += 1
                previous = date
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

    private static func isSkipOrSnooze(_ log: HabitLogSnapshot) -> Bool {
        log.memo == skipMemoMarker || log.memo == snoozeMemoMarker
    }
}
