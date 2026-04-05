import Testing
import SwiftData
@testable import DUNE

@Suite("HabitCycleSnapshot Tests")
struct HabitCycleSnapshotTests {
    let calendar = Calendar.current
    let viewModel = LifeViewModel()

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: HabitDefinition.self, HabitLog.self,
            configurations: config
        )
    }

    private func makeIntervalHabit(
        intervalDays: Int,
        createdAt: Date,
        container: ModelContainer
    ) -> HabitDefinition {
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
        // Override createdAt since init sets Date()
        habit.createdAt = createdAt
        habit.recurringStartConfiguredAt = calendar.startOfDay(for: createdAt)
        let context = container.mainContext
        context.insert(habit)
        return habit
    }

    private func addCompletionLog(
        to habit: HabitDefinition,
        on date: Date,
        container: ModelContainer
    ) {
        let log = HabitLog(date: calendar.startOfDay(for: date), value: 1)
        log.habitDefinition = habit
        if habit.logs == nil { habit.logs = [] }
        habit.logs?.append(log)
        container.mainContext.insert(log)
    }

    // MARK: - Early Completion Bug Fix

    @Test("Early completion allowed — completed days ago, next due tomorrow")
    @MainActor
    func earlyCompletionBeforeDueDate() throws {
        let container = try makeContainer()
        let march30 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 30))!
        let april5 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5))!

        let habit = makeIntervalHabit(intervalDays: 7, createdAt: march30, container: container)
        addCompletionLog(to: habit, on: march30, container: container)

        let snapshot = viewModel.cycleSnapshot(for: habit, referenceDate: april5)

        #expect(snapshot != nil)
        #expect(snapshot?.canComplete == true, "Should allow early completion before due date")
        #expect(snapshot?.isDue == false)
        // Due date should be April 6 (March 30 + 7 days)
        let expectedDue = calendar.date(from: DateComponents(year: 2026, month: 4, day: 6))!
        #expect(snapshot?.nextDueDate == expectedDue)
    }

    @Test("Same-day double-tap blocked — completed today")
    @MainActor
    func sameDayDoubleTapBlocked() throws {
        let container = try makeContainer()
        let march30 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 30))!
        let april5 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5))!

        let habit = makeIntervalHabit(intervalDays: 7, createdAt: march30, container: container)
        addCompletionLog(to: habit, on: april5, container: container)

        let snapshot = viewModel.cycleSnapshot(for: habit, referenceDate: april5)

        #expect(snapshot != nil)
        #expect(snapshot?.canComplete == false, "Should block same-day double-tap")
    }

    @Test("First cycle no logs — can complete")
    @MainActor
    func firstCycleNoLogs() throws {
        let container = try makeContainer()
        let april1 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let april5 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5))!

        let habit = makeIntervalHabit(intervalDays: 7, createdAt: april1, container: container)

        let snapshot = viewModel.cycleSnapshot(for: habit, referenceDate: april5)

        #expect(snapshot != nil)
        #expect(snapshot?.canComplete == true, "Should allow first completion")
        #expect(snapshot?.isDue == false)
    }

    @Test("Due date reached — completed yesterday, can complete on due day")
    @MainActor
    func dueDateReachedCanComplete() throws {
        let container = try makeContainer()
        let march30 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 30))!
        let april5 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5))!
        let april6 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 6))!

        let habit = makeIntervalHabit(intervalDays: 7, createdAt: march30, container: container)
        addCompletionLog(to: habit, on: april5, container: container)

        // Reference date = April 6 (due date after April 5 early-completion → April 12)
        let snapshot = viewModel.cycleSnapshot(for: habit, referenceDate: april6)

        #expect(snapshot != nil)
        #expect(snapshot?.canComplete == true, "Should allow completion on a different day")
    }

    @Test("Due date same-day completion — blocked")
    @MainActor
    func dueDateSameDayCompletion() throws {
        let container = try makeContainer()
        let march30 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 30))!
        let april6 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 6))!

        let habit = makeIntervalHabit(intervalDays: 7, createdAt: march30, container: container)
        addCompletionLog(to: habit, on: april6, container: container)

        let snapshot = viewModel.cycleSnapshot(for: habit, referenceDate: april6)

        #expect(snapshot != nil)
        #expect(snapshot?.canComplete == false, "Should block same-day re-completion")
    }
}
