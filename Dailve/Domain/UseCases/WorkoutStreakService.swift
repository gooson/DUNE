import Foundation

/// Calculates workout streak and monthly consistency from workout dates.
enum WorkoutStreakService: Sendable {

    struct WorkoutDay: Sendable {
        let date: Date
        let durationMinutes: Double
    }

    /// Calculates current streak, best streak, and monthly workout count.
    /// - Parameter workouts: List of workout dates + durations.
    /// - Parameter minimumMinutes: Minimum duration (minutes) to count as a valid workout day.
    /// - Parameter referenceDate: "Today" for streak calculation.
    /// - Parameter monthlyGoal: Monthly workout target (default: 16 = ~4/week).
    /// - Returns: WorkoutStreak with all metrics.
    static func calculate(
        from workouts: [WorkoutDay],
        minimumMinutes: Double = 20,
        referenceDate: Date = Date(),
        monthlyGoal: Int = 16
    ) -> WorkoutStreak {
        guard !workouts.isEmpty else {
            return WorkoutStreak(currentStreak: 0, bestStreak: 0, monthlyCount: 0, monthlyGoal: monthlyGoal)
        }

        let calendar = Calendar.current
        let clampedMinimum = max(0, min(1440, minimumMinutes))  // Correction #84: max 1440 min

        // Filter valid workouts and extract unique days
        let validDays: Set<DateComponents> = Set(
            workouts
                .filter { $0.durationMinutes >= clampedMinimum }
                .map { calendar.dateComponents([.year, .month, .day], from: $0.date) }
        )

        guard !validDays.isEmpty else {
            return WorkoutStreak(currentStreak: 0, bestStreak: 0, monthlyCount: 0, monthlyGoal: monthlyGoal)
        }

        // Sort unique dates descending (most recent first)
        let sortedDates = validDays.compactMap { calendar.date(from: $0) }.sorted(by: >)

        // Current streak: consecutive days ending at today or yesterday
        let currentStreak = computeCurrentStreak(
            sortedDates: sortedDates,
            referenceDate: referenceDate,
            calendar: calendar
        )

        // Best streak: longest consecutive sequence in entire history
        let bestStreak = computeBestStreak(sortedDates: sortedDates, calendar: calendar)

        // Monthly count: workouts in current calendar month
        let currentMonth = calendar.dateComponents([.year, .month], from: referenceDate)
        let monthlyCount = validDays.filter { dc in
            dc.year == currentMonth.year && dc.month == currentMonth.month
        }.count

        return WorkoutStreak(
            currentStreak: currentStreak,
            bestStreak: max(currentStreak, bestStreak),
            monthlyCount: monthlyCount,
            monthlyGoal: monthlyGoal
        )
    }

    /// Extracts all streak periods (consecutive workout day sequences) from history.
    /// - Parameter workouts: List of workout dates + durations.
    /// - Parameter minimumMinutes: Minimum duration to count as a valid day.
    /// - Returns: Array of StreakPeriod sorted by startDate descending (most recent first).
    static func extractStreakHistory(
        from workouts: [WorkoutDay],
        minimumMinutes: Double = 20
    ) -> [StreakPeriod] {
        guard !workouts.isEmpty else { return [] }

        let calendar = Calendar.current
        let clampedMinimum = max(0, min(1440, minimumMinutes))

        // Unique valid days, ascending
        let uniqueDays: [Date] = Set(
            workouts
                .filter { $0.durationMinutes >= clampedMinimum }
                .map { calendar.startOfDay(for: $0.date) }
        )
        .sorted()

        guard !uniqueDays.isEmpty else { return [] }

        var streaks: [StreakPeriod] = []
        var streakStart = uniqueDays[0]
        var prev = uniqueDays[0]

        for day in uniqueDays.dropFirst() {
            let diff = calendar.dateComponents([.day], from: prev, to: day).day ?? 0
            if diff == 1 {
                // Continue current streak
                prev = day
            } else {
                // End current streak, start new one
                let days = (calendar.dateComponents([.day], from: streakStart, to: prev).day ?? 0) + 1
                streaks.append(StreakPeriod(id: streakStart, startDate: streakStart, endDate: prev, days: days))
                streakStart = day
                prev = day
            }
        }

        // Finalize last streak
        let lastDays = (calendar.dateComponents([.day], from: streakStart, to: prev).day ?? 0) + 1
        streaks.append(StreakPeriod(id: streakStart, startDate: streakStart, endDate: prev, days: lastDays))

        // Return sorted by startDate descending (most recent first)
        return streaks.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Private

    private static func computeCurrentStreak(
        sortedDates: [Date],
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        let today = calendar.startOfDay(for: referenceDate)
        guard let mostRecent = sortedDates.first else { return 0 }

        let mostRecentDay = calendar.startOfDay(for: mostRecent)
        let daysSinceLast = calendar.dateComponents([.day], from: mostRecentDay, to: today).day ?? 0

        // Streak is alive if last workout was today or yesterday
        guard daysSinceLast >= 0 && daysSinceLast <= 1 else { return 0 }

        var streak = 1
        var previousDay = mostRecentDay

        for date in sortedDates.dropFirst() {
            let day = calendar.startOfDay(for: date)
            let diff = calendar.dateComponents([.day], from: day, to: previousDay).day ?? 0
            if diff == 1 {
                streak += 1
                previousDay = day
            } else if diff == 0 {
                continue  // Same day, skip
            } else {
                break  // Gap found
            }
        }

        return streak
    }

    private static func computeBestStreak(sortedDates: [Date], calendar: Calendar) -> Int {
        guard sortedDates.count >= 2 else { return sortedDates.count }

        // Reverse to ascending order for forward scan
        let ascending = sortedDates.reversed().map { calendar.startOfDay(for: $0) }
        // Deduplicate
        var unique: [Date] = []
        for date in ascending {
            if unique.last != date { unique.append(date) }
        }

        guard unique.count >= 2 else { return unique.count }

        var best = 1
        var current = 1

        for i in 1..<unique.count {
            let diff = calendar.dateComponents([.day], from: unique[i - 1], to: unique[i]).day ?? 0
            if diff == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }

        return best
    }
}
