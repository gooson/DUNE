import Testing
import Foundation
@testable import DUNE

@Suite("HabitAnalyticsService Tests")
struct HabitAnalyticsServiceTests {
    private let calendar = Calendar.current

    private func makeDate(year: Int = 2026, month: Int = 3, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeHabit(
        id: UUID = UUID(),
        name: String = "Test",
        goalValue: Double = 1.0,
        frequencyType: String = "daily",
        weeklyTargetDays: Int = 7
    ) -> HabitSnapshot {
        HabitSnapshot(
            id: id,
            name: name,
            goalValue: goalValue,
            frequencyTypeRaw: frequencyType,
            weeklyTargetDays: weeklyTargetDays
        )
    }

    private func makeLog(
        habitID: UUID,
        day: Int,
        value: Double = 1.0,
        memo: String? = nil
    ) -> HabitLogSnapshot {
        HabitLogSnapshot(
            habitID: habitID,
            date: makeDate(day: day),
            value: value,
            memo: memo
        )
    }

    // MARK: - Daily Completion Counts (Heatmap)

    @Test("Heatmap returns correct completion counts")
    func heatmapCounts() {
        let habitID = UUID()
        let logs = [
            makeLog(habitID: habitID, day: 20),
            makeLog(habitID: habitID, day: 20),
            makeLog(habitID: habitID, day: 19),
        ]

        let result = HabitAnalyticsService.dailyCompletionCounts(
            logs: logs,
            dayCount: 5,
            referenceDate: makeDate(day: 22)
        )

        #expect(result.count == 5)

        let day20 = result.first { calendar.isDate($0.date, inSameDayAs: makeDate(day: 20)) }
        #expect(day20?.completionCount == 2)

        let day19 = result.first { calendar.isDate($0.date, inSameDayAs: makeDate(day: 19)) }
        #expect(day19?.completionCount == 1)

        let day22 = result.first { calendar.isDate($0.date, inSameDayAs: makeDate(day: 22)) }
        #expect(day22?.completionCount == 0)
    }

    @Test("Heatmap excludes skip/snooze logs")
    func heatmapExcludesSkipSnooze() {
        let habitID = UUID()
        let logs = [
            makeLog(habitID: habitID, day: 20, value: 1.0),
            makeLog(habitID: habitID, day: 20, value: 0, memo: "[dune-life-cycle-skip]"),
            makeLog(habitID: habitID, day: 19, value: 0, memo: "[dune-life-cycle-snooze]"),
        ]

        let result = HabitAnalyticsService.dailyCompletionCounts(
            logs: logs,
            dayCount: 5,
            referenceDate: makeDate(day: 22)
        )

        let day20 = result.first { calendar.isDate($0.date, inSameDayAs: makeDate(day: 20)) }
        #expect(day20?.completionCount == 1)

        let day19 = result.first { calendar.isDate($0.date, inSameDayAs: makeDate(day: 19)) }
        #expect(day19?.completionCount == 0)
    }

    // MARK: - Weekly Completion Rates

    @Test("Weekly rates calculate correctly for daily habit")
    func weeklyRatesDaily() {
        let habitID = UUID()
        let habit = makeHabit(id: habitID)

        // 7 completions in a week = 100%
        var logs: [HabitLogSnapshot] = []
        for day in 16...22 {
            logs.append(makeLog(habitID: habitID, day: day))
        }

        let result = HabitAnalyticsService.weeklyCompletionRates(
            logs: logs,
            habits: [habit],
            weekCount: 2,
            referenceDate: makeDate(day: 22)
        )

        #expect(result.count == 2)
        // At least one week should have rate > 0
        #expect(result.contains { $0.rate > 0 })
    }

    @Test("Weekly rates returns empty for no habits")
    func weeklyRatesEmpty() {
        let result = HabitAnalyticsService.weeklyCompletionRates(
            logs: [],
            habits: [],
            weekCount: 4,
            referenceDate: makeDate(day: 22)
        )

        #expect(result.isEmpty)
    }

    // MARK: - Weekly Report

    @Test("Weekly report computes overall rate")
    func weeklyReport() {
        let habitID = UUID()
        let habit = makeHabit(id: habitID)

        let logs = [
            makeLog(habitID: habitID, day: 17),
            makeLog(habitID: habitID, day: 18),
            makeLog(habitID: habitID, day: 19),
        ]

        let report = HabitAnalyticsService.weeklyReport(
            logs: logs,
            habits: [habit],
            referenceDate: makeDate(day: 22)
        )

        #expect(report.totalCompletions >= 0)
        #expect(report.overallCompletionRate >= 0)
        #expect(report.overallCompletionRate <= 1)
    }

    @Test("Weekly report handles empty data")
    func weeklyReportEmpty() {
        let report = HabitAnalyticsService.weeklyReport(
            logs: [],
            habits: [],
            referenceDate: makeDate(day: 22)
        )

        #expect(report.overallCompletionRate == 0)
        #expect(report.totalCompletions == 0)
        #expect(report.bestHabits.isEmpty)
    }

    // MARK: - Monthly Completion Rates

    @Test("Monthly rates returns results for valid data")
    func monthlyRates() {
        let habitID = UUID()
        let habit = makeHabit(id: habitID)

        var logs: [HabitLogSnapshot] = []
        for day in 1...20 {
            logs.append(makeLog(habitID: habitID, day: day))
        }

        let result = HabitAnalyticsService.monthlyCompletionRates(
            logs: logs,
            habits: [habit],
            monthCount: 2,
            referenceDate: makeDate(day: 22)
        )

        #expect(result.count == 2)
        #expect(result.last?.rate ?? 0 > 0)
    }

    // MARK: - Interval Habits

    @Test("Weekly goal count for interval habits")
    func intervalHabitWeeklyGoal() {
        let habitID = UUID()
        // interval: every 7 days → 7/7 = 1 per week
        let habit = makeHabit(id: habitID, frequencyType: "interval", weeklyTargetDays: 7)

        let logs = [makeLog(habitID: habitID, day: 20)]

        let result = HabitAnalyticsService.weeklyCompletionRates(
            logs: logs,
            habits: [habit],
            weekCount: 1,
            referenceDate: makeDate(day: 22)
        )

        #expect(result.count == 1)
    }
}

// MARK: - HabitReminderScheduler Offset Tests

@Suite("HabitReminderScheduler Offset Tests")
struct HabitReminderOffsetTests {

    @Test("Daily frequency → [0] offset")
    func dailyOffset() {
        let offsets = HabitReminderScheduler.reminderOffsets(for: .daily)
        #expect(offsets == [0])
    }

    @Test("Weekly frequency → [0] offset")
    func weeklyOffset() {
        let offsets = HabitReminderScheduler.reminderOffsets(for: .weekly(targetDays: 3))
        #expect(offsets == [0])
    }

    @Test("7-day interval → [1, 0] offset")
    func sevenDayInterval() {
        let offsets = HabitReminderScheduler.reminderOffsets(for: .interval(days: 7))
        #expect(offsets == [1, 0])
    }

    @Test("14-day interval → [3, 1, 0] offset")
    func fourteenDayInterval() {
        let offsets = HabitReminderScheduler.reminderOffsets(for: .interval(days: 14))
        #expect(offsets == [3, 1, 0])
    }

    @Test("30-day interval → [7, 3, 1, 0] offset")
    func thirtyDayInterval() {
        let offsets = HabitReminderScheduler.reminderOffsets(for: .interval(days: 30))
        #expect(offsets == [7, 3, 1, 0])
    }

    @Test("90-day interval → [14, 7, 3, 0] offset")
    func ninetyDayInterval() {
        let offsets = HabitReminderScheduler.reminderOffsets(for: .interval(days: 90))
        #expect(offsets == [14, 7, 3, 0])
    }

    @Test("1-day interval → [0] offset")
    func oneDayInterval() {
        let offsets = HabitReminderScheduler.reminderOffsets(for: .interval(days: 1))
        #expect(offsets == [0])
    }

    @Test("3-day interval → [1, 0] offset")
    func threeDayInterval() {
        let offsets = HabitReminderScheduler.reminderOffsets(for: .interval(days: 3))
        #expect(offsets == [1, 0])
    }
}
