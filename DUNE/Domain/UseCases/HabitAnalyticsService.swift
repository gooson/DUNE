import Foundation

// MARK: - Analytics Data Types

struct WeeklyCompletionRate: Sendable, Identifiable {
    let id: Date // week start date
    let weekStart: Date
    let completedCount: Int
    let totalGoalCount: Int

    var rate: Double {
        totalGoalCount > 0 ? Double(completedCount) / Double(totalGoalCount) : 0
    }
}

struct MonthlyCompletionRate: Sendable, Identifiable {
    let id: Date // month start date
    let monthStart: Date
    let completedCount: Int
    let totalGoalCount: Int

    var rate: Double {
        totalGoalCount > 0 ? Double(completedCount) / Double(totalGoalCount) : 0
    }
}

struct DailyCompletionCount: Sendable, Identifiable {
    let id: Date // the day
    let date: Date
    let completionCount: Int
}

struct WeeklyHabitReport: Sendable {
    let weekStart: Date
    let weekEnd: Date
    let overallCompletionRate: Double
    let previousWeekRate: Double
    let totalCompletions: Int
    let totalGoals: Int
    let bestHabits: [(name: String, rate: Double)]
    let worstHabits: [(name: String, rate: Double)]
    let longestStreak: (name: String, streak: Int)?
}

// MARK: - Lightweight Snapshots (SwiftData-free)

struct HabitLogSnapshot: Sendable {
    let habitID: UUID
    let date: Date
    let value: Double
    let memo: String?
}

struct HabitSnapshot: Sendable {
    let id: UUID
    let name: String
    let goalValue: Double
    let frequencyTypeRaw: String
    let weeklyTargetDays: Int
}

// MARK: - Service

enum HabitAnalyticsService {

    // MARK: - Weekly Completion Rates

    static func weeklyCompletionRates(
        logs: [HabitLogSnapshot],
        habits: [HabitSnapshot],
        weekCount: Int = 8,
        referenceDate: Date = Date()
    ) -> [WeeklyCompletionRate] {
        let calendar = Calendar.current
        guard !habits.isEmpty else { return [] }

        let validLogs = logs.filter { isCompletionLog($0) }
        var results: [WeeklyCompletionRate] = []

        for weekOffset in 0..<weekCount {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: calendar.startOfDay(for: referenceDate)),
                  let adjustedWeekStart = calendar.dateInterval(of: .weekOfYear, for: weekStart)?.start else { continue }
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: adjustedWeekStart) ?? adjustedWeekStart

            let weekLogs = validLogs.filter { $0.date >= adjustedWeekStart && $0.date < weekEnd }

            var totalGoals = 0
            var completions = 0

            for habit in habits {
                let goalPerWeek = weeklyGoalCount(for: habit)
                totalGoals += goalPerWeek
                let habitLogs = weekLogs.filter { $0.habitID == habit.id && $0.value >= habit.goalValue }
                completions += min(habitLogs.count, goalPerWeek)
            }

            results.append(WeeklyCompletionRate(
                id: adjustedWeekStart,
                weekStart: adjustedWeekStart,
                completedCount: completions,
                totalGoalCount: totalGoals
            ))
        }

        return results.reversed()
    }

    // MARK: - Monthly Completion Rates

    static func monthlyCompletionRates(
        logs: [HabitLogSnapshot],
        habits: [HabitSnapshot],
        monthCount: Int = 6,
        referenceDate: Date = Date()
    ) -> [MonthlyCompletionRate] {
        let calendar = Calendar.current
        guard !habits.isEmpty else { return [] }

        let validLogs = logs.filter { isCompletionLog($0) }
        var results: [MonthlyCompletionRate] = []

        for monthOffset in 0..<monthCount {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: referenceDate),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else { continue }

            let daysInMonth = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 30
            let monthLogs = validLogs.filter { $0.date >= monthInterval.start && $0.date < monthInterval.end }

            var totalGoals = 0
            var completions = 0

            for habit in habits {
                let goalPerMonth = monthlyGoalCount(for: habit, daysInMonth: daysInMonth)
                totalGoals += goalPerMonth
                let habitLogs = monthLogs.filter { $0.habitID == habit.id && $0.value >= habit.goalValue }
                completions += min(habitLogs.count, goalPerMonth)
            }

            results.append(MonthlyCompletionRate(
                id: monthInterval.start,
                monthStart: monthInterval.start,
                completedCount: completions,
                totalGoalCount: totalGoals
            ))
        }

        return results.reversed()
    }

    // MARK: - Daily Completion Counts (Heatmap)

    static func dailyCompletionCounts(
        logs: [HabitLogSnapshot],
        dayCount: Int = 90,
        referenceDate: Date = Date()
    ) -> [DailyCompletionCount] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        let validLogs = logs.filter { isCompletionLog($0) }

        // Group logs by day
        var countByDay: [Date: Int] = [:]
        for log in validLogs {
            let day = calendar.startOfDay(for: log.date)
            countByDay[day, default: 0] += 1
        }

        var results: [DailyCompletionCount] = []
        for dayOffset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            results.append(DailyCompletionCount(
                id: day,
                date: day,
                completionCount: countByDay[day] ?? 0
            ))
        }

        return results.reversed()
    }

    // MARK: - Weekly Report

    static func weeklyReport(
        logs: [HabitLogSnapshot],
        habits: [HabitSnapshot],
        referenceDate: Date = Date()
    ) -> WeeklyHabitReport {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        guard let thisWeekInterval = calendar.dateInterval(of: .weekOfYear, for: today) else {
            return emptyReport(referenceDate: today)
        }

        let thisWeekStart = thisWeekInterval.start
        let thisWeekEnd = calendar.date(byAdding: .day, value: 7, to: thisWeekStart) ?? thisWeekStart
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart

        let validLogs = logs.filter { isCompletionLog($0) }
        let thisWeekLogs = validLogs.filter { $0.date >= thisWeekStart && $0.date < thisWeekEnd }
        let lastWeekLogs = validLogs.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }

        // Overall rates
        var thisWeekTotal = 0
        var thisWeekCompleted = 0
        var lastWeekTotal = 0
        var lastWeekCompleted = 0
        var habitRates: [(name: String, rate: Double)] = []

        for habit in habits {
            let goalPerWeek = weeklyGoalCount(for: habit)

            let thisCount = min(
                thisWeekLogs.filter { $0.habitID == habit.id && $0.value >= habit.goalValue }.count,
                goalPerWeek
            )
            let lastCount = min(
                lastWeekLogs.filter { $0.habitID == habit.id && $0.value >= habit.goalValue }.count,
                goalPerWeek
            )

            thisWeekTotal += goalPerWeek
            thisWeekCompleted += thisCount
            lastWeekTotal += goalPerWeek
            lastWeekCompleted += lastCount

            let rate = goalPerWeek > 0 ? Double(thisCount) / Double(goalPerWeek) : 0
            habitRates.append((name: habit.name, rate: rate))
        }

        let overallRate = thisWeekTotal > 0 ? Double(thisWeekCompleted) / Double(thisWeekTotal) : 0
        let prevRate = lastWeekTotal > 0 ? Double(lastWeekCompleted) / Double(lastWeekTotal) : 0

        let sorted = habitRates.sorted { $0.rate > $1.rate }
        let best = Array(sorted.prefix(3))
        let worst = Array(sorted.suffix(3).reversed())

        return WeeklyHabitReport(
            weekStart: thisWeekStart,
            weekEnd: thisWeekEnd,
            overallCompletionRate: overallRate,
            previousWeekRate: prevRate,
            totalCompletions: thisWeekCompleted,
            totalGoals: thisWeekTotal,
            bestHabits: best,
            worstHabits: worst,
            longestStreak: nil // Streak requires full log history; omit from weekly report
        )
    }

    // MARK: - Helpers

    private static func isCompletionLog(_ log: HabitLogSnapshot) -> Bool {
        guard log.value > 0 else { return false }
        if let memo = log.memo {
            return memo != "[dune-life-cycle-skip]" && memo != "[dune-life-cycle-snooze]"
        }
        return true
    }

    private static func weeklyGoalCount(for habit: HabitSnapshot) -> Int {
        switch habit.frequencyTypeRaw {
        case "daily": return 7
        case "weekly": return max(1, min(habit.weeklyTargetDays, 7))
        case "interval":
            let interval = max(1, habit.weeklyTargetDays)
            return max(1, 7 / interval)
        default: return 7
        }
    }

    private static func monthlyGoalCount(for habit: HabitSnapshot, daysInMonth: Int) -> Int {
        switch habit.frequencyTypeRaw {
        case "daily": return daysInMonth
        case "weekly": return max(1, min(habit.weeklyTargetDays, 7)) * (daysInMonth / 7)
        case "interval":
            let interval = max(1, habit.weeklyTargetDays)
            return max(1, daysInMonth / interval)
        default: return daysInMonth
        }
    }

    private static func emptyReport(referenceDate: Date) -> WeeklyHabitReport {
        WeeklyHabitReport(
            weekStart: referenceDate,
            weekEnd: referenceDate,
            overallCompletionRate: 0,
            previousWeekRate: 0,
            totalCompletions: 0,
            totalGoals: 0,
            bestHabits: [],
            worstHabits: [],
            longestStreak: nil
        )
    }
}
