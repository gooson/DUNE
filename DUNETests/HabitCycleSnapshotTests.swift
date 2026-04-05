import Foundation
import Testing
@testable import DUNE

@Suite("HabitCycleSnapshot Tests")
@MainActor
struct HabitCycleSnapshotTests {
    let calendar = Calendar.current
    let viewModel = LifeViewModel()

    private func makeDate(year: Int = 2026, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeIntervalHabit(intervalDays: Int, createdAt: Date) -> HabitDefinition {
        let habit = HabitDefinition(
            name: "Test Habit",
            iconCategory: .health,
            habitType: .check,
            goalValue: 1,
            goalUnit: nil,
            frequency: .interval(days: intervalDays),
            recurringStartPoint: .createdAt,
            recurringStartConfiguredAt: createdAt
        )
        habit.createdAt = createdAt
        habit.recurringStartConfiguredAt = calendar.startOfDay(for: createdAt)
        habit.logs = []
        return habit
    }

    private func addCompletionLog(to habit: HabitDefinition, on date: Date) {
        let log = HabitLog(date: calendar.startOfDay(for: date), value: 1)
        log.habitDefinition = habit
        habit.logs?.append(log)
    }

    // MARK: - Early Completion Bug Fix

    @Test("Early completion allowed — completed days ago, next due tomorrow")
    func earlyCompletionBeforeDueDate() {
        let march30 = makeDate(month: 3, day: 30)
        let april5 = makeDate(month: 4, day: 5)

        let habit = makeIntervalHabit(intervalDays: 7, createdAt: march30)
        addCompletionLog(to: habit, on: march30)

        let snapshot = viewModel.cycleSnapshot(for: habit, referenceDate: april5)

        #expect(snapshot != nil)
        #expect(snapshot?.canComplete == true, "Should allow early completion before due date")
        #expect(snapshot?.isDue == false)
        #expect(snapshot?.nextDueDate == makeDate(month: 4, day: 6))
    }

    @Test("Same-day double-tap blocked — completed today")
    func sameDayDoubleTapBlocked() {
        let march30 = makeDate(month: 3, day: 30)
        let april5 = makeDate(month: 4, day: 5)

        let habit = makeIntervalHabit(intervalDays: 7, createdAt: march30)
        addCompletionLog(to: habit, on: april5)

        let snapshot = viewModel.cycleSnapshot(for: habit, referenceDate: april5)

        #expect(snapshot != nil)
        #expect(snapshot?.canComplete == false, "Should block same-day double-tap")
    }

    @Test("First cycle no logs — can complete")
    func firstCycleNoLogs() {
        let april1 = makeDate(month: 4, day: 1)
        let april5 = makeDate(month: 4, day: 5)

        let habit = makeIntervalHabit(intervalDays: 7, createdAt: april1)

        let snapshot = viewModel.cycleSnapshot(for: habit, referenceDate: april5)

        #expect(snapshot != nil)
        #expect(snapshot?.canComplete == true, "Should allow first completion")
        #expect(snapshot?.isDue == false)
    }

    @Test("Due date reached — completed yesterday, can complete on due day")
    func dueDateReachedCanComplete() {
        let march30 = makeDate(month: 3, day: 30)
        let april5 = makeDate(month: 4, day: 5)
        let april6 = makeDate(month: 4, day: 6)

        let habit = makeIntervalHabit(intervalDays: 7, createdAt: march30)
        addCompletionLog(to: habit, on: april5)

        let snapshot = viewModel.cycleSnapshot(for: habit, referenceDate: april6)

        #expect(snapshot != nil)
        #expect(snapshot?.canComplete == true, "Should allow completion on a different day")
    }

    @Test("Due date same-day completion — blocked")
    func dueDateSameDayCompletion() {
        let march30 = makeDate(month: 3, day: 30)
        let april6 = makeDate(month: 4, day: 6)

        let habit = makeIntervalHabit(intervalDays: 7, createdAt: march30)
        addCompletionLog(to: habit, on: april6)

        let snapshot = viewModel.cycleSnapshot(for: habit, referenceDate: april6)

        #expect(snapshot != nil)
        #expect(snapshot?.canComplete == false, "Should block same-day re-completion")
    }
}
