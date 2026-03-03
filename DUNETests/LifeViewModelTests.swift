import Foundation
import Testing
@testable import DUNE

@Suite("LifeViewModel")
@MainActor
struct LifeViewModelTests {

    // MARK: - createValidatedHabit

    @Test("createValidatedHabit returns habit with valid inputs")
    func validHabit() {
        let vm = LifeViewModel()
        vm.name = "Take vitamins"
        vm.selectedIconCategory = .health
        vm.selectedType = .check
        vm.frequencyType = "daily"

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.name == "Take vitamins")
        #expect(habit?.habitType == .check)
        #expect(habit?.iconCategory == .health)
        #expect(habit?.goalValue == 1.0)
        #expect(vm.validationError == nil)
        // Correction #43: isSaving stays true until didFinishSaving
        #expect(vm.isSaving == true)
        vm.didFinishSaving()
        #expect(vm.isSaving == false)
    }

    @Test("createValidatedHabit fails for empty name")
    func emptyName() {
        let vm = LifeViewModel()
        vm.name = ""
        vm.selectedType = .check

        let habit = vm.createValidatedHabit()
        #expect(habit == nil)
        #expect(vm.validationError != nil)
        #expect(vm.validationError == String(localized: "Habit name is required"))
    }

    @Test("createValidatedHabit fails for whitespace-only name")
    func whitespaceOnlyName() {
        let vm = LifeViewModel()
        vm.name = "   "
        vm.selectedType = .check

        let habit = vm.createValidatedHabit()
        #expect(habit == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedHabit blocks duplicate save with isSaving")
    func isSavingGuard() {
        let vm = LifeViewModel()
        vm.name = "Test"
        vm.selectedType = .check

        _ = vm.createValidatedHabit()
        #expect(vm.isSaving == true)

        // Second call should return nil
        let second = vm.createValidatedHabit()
        #expect(second == nil)
    }

    @Test("createValidatedHabit validates duration goal > 0")
    func durationGoalZero() {
        let vm = LifeViewModel()
        vm.name = "Coding"
        vm.selectedType = .duration
        vm.goalValue = "0"

        let habit = vm.createValidatedHabit()
        #expect(habit == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedHabit validates duration goal within max")
    func durationGoalOverMax() {
        let vm = LifeViewModel()
        vm.name = "Coding"
        vm.selectedType = .duration
        vm.goalValue = "2000"

        let habit = vm.createValidatedHabit()
        #expect(habit == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedHabit validates count goal > 0")
    func countGoalZero() {
        let vm = LifeViewModel()
        vm.name = "Water"
        vm.selectedType = .count
        vm.goalValue = "-1"

        let habit = vm.createValidatedHabit()
        #expect(habit == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedHabit creates duration habit correctly")
    func validDurationHabit() {
        let vm = LifeViewModel()
        vm.name = "Coding"
        vm.selectedIconCategory = .coding
        vm.selectedType = .duration
        vm.goalValue = "60"
        vm.goalUnit = "min"
        vm.frequencyType = "daily"

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.habitType == .duration)
        #expect(habit?.goalValue == 60.0)
        #expect(habit?.goalUnit == "min")
        vm.didFinishSaving()
    }

    @Test("createValidatedHabit creates weekly habit correctly")
    func validWeeklyHabit() {
        let vm = LifeViewModel()
        vm.name = "Exercise"
        vm.selectedType = .check
        vm.frequencyType = "weekly"
        vm.weeklyTargetDays = 4

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.frequency == .weekly(targetDays: 4))
        vm.didFinishSaving()
    }

    @Test("createValidatedHabit creates interval habit correctly")
    func validIntervalHabit() {
        let vm = LifeViewModel()
        vm.name = "Filter replacement"
        vm.selectedType = .check
        vm.frequencyType = "interval"
        vm.intervalDays = 90

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.frequency == .interval(days: 90))
        vm.didFinishSaving()
    }

    @Test("createValidatedHabit clamps interval days to max")
    func intervalClampedToMax() {
        let vm = LifeViewModel()
        vm.name = "Long cycle"
        vm.selectedType = .check
        vm.frequencyType = "interval"
        vm.intervalDays = 999

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.frequency == .interval(days: 365))
        vm.didFinishSaving()
    }

    @Test("createValidatedHabit creates auto-linked habit")
    func autoLinkedHabit() {
        let vm = LifeViewModel()
        vm.name = "Daily workout"
        vm.selectedType = .check
        vm.isAutoLinked = true

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.isAutoLinked == true)
        #expect(habit?.autoLinkSourceRaw == "exercise")
        vm.didFinishSaving()
    }

    // MARK: - didFinishSaving

    @Test("didFinishSaving resets isSaving flag")
    func didFinishSaving() {
        let vm = LifeViewModel()
        vm.name = "Test"
        _ = vm.createValidatedHabit()
        #expect(vm.isSaving == true)

        vm.didFinishSaving()
        #expect(vm.isSaving == false)
    }

    // MARK: - resetForm

    @Test("resetForm clears all fields")
    func resetForm() {
        let vm = LifeViewModel()
        vm.name = "Custom habit"
        vm.selectedIconCategory = .coding
        vm.selectedType = .duration
        vm.goalValue = "30"
        vm.goalUnit = "min"
        vm.frequencyType = "weekly"
        vm.weeklyTargetDays = 5
        vm.isAutoLinked = true
        vm.validationError = "Some error"

        vm.resetForm()

        #expect(vm.name == "")
        #expect(vm.selectedIconCategory == .health)
        #expect(vm.selectedType == .check)
        #expect(vm.goalValue == "1")
        #expect(vm.goalUnit == "")
        #expect(vm.frequencyType == "daily")
        #expect(vm.weeklyTargetDays == 3)
        #expect(vm.intervalDays == 7)
        #expect(vm.isAutoLinked == false)
        #expect(vm.validationError == nil)
    }

    // MARK: - Name validation clears error

    @Test("setting name clears validationError")
    func nameSetClearsError() {
        let vm = LifeViewModel()
        vm.validationError = "Some error"
        vm.name = "New name"
        #expect(vm.validationError == nil)
    }

    // MARK: - Name truncation

    @Test("createValidatedHabit truncates long names")
    func nameTruncation() {
        let vm = LifeViewModel()
        vm.name = String(repeating: "A", count: 100)
        vm.selectedType = .check

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit!.name.count == 50)
        vm.didFinishSaving()
    }

    // MARK: - Cycle Snapshot / History

    @Test("cycle snapshot uses completion date and snooze override")
    func cycleSnapshotWithSnooze() {
        let vm = LifeViewModel()
        let calendar = Calendar.current
        let createdAt = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_704_067_200)) // 2024-01-01
        let completedAt = calendar.date(byAdding: .day, value: 2, to: createdAt)!
        let snoozedTo = calendar.date(byAdding: .day, value: 15, to: createdAt)!
        let referenceDate = calendar.date(byAdding: .day, value: 10, to: createdAt)!

        let habit = HabitDefinition(
            name: "Water filter",
            iconCategory: .chores,
            habitType: .check,
            goalValue: 1,
            goalUnit: nil,
            frequency: .interval(days: 7)
        )
        habit.createdAt = createdAt

        let completion = vm.createCycleActionLog(for: habit, action: .complete, date: completedAt)
        #expect(completion != nil)
        vm.didFinishSaving()

        let snooze = vm.createCycleActionLog(for: habit, action: .snooze, date: snoozedTo)
        #expect(snooze != nil)
        vm.didFinishSaving()

        completion?.habitDefinition = habit
        snooze?.habitDefinition = habit
        habit.logs = [completion, snooze].compactMap { $0 }

        let snapshot = vm.cycleSnapshot(for: habit, referenceDate: referenceDate)
        #expect(snapshot != nil)
        #expect(snapshot?.nextDueDate == calendar.startOfDay(for: snoozedTo))
        #expect(snapshot?.isDue == false)
        #expect(snapshot?.lastAction == .complete)
    }

    @Test("history entries are sorted newest first with cycle action parsing")
    func historyEntriesSortedAndParsed() {
        let vm = LifeViewModel()
        let calendar = Calendar.current
        let createdAt = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_704_067_200)) // 2024-01-01
        let completeDate = calendar.date(byAdding: .day, value: 1, to: createdAt)!
        let skipDate = calendar.date(byAdding: .day, value: 2, to: createdAt)!
        let snoozeDate = calendar.date(byAdding: .day, value: 3, to: createdAt)!

        let habit = HabitDefinition(
            name: "Recycling",
            iconCategory: .chores,
            habitType: .check,
            goalValue: 1,
            goalUnit: nil,
            frequency: .interval(days: 7)
        )
        habit.createdAt = createdAt

        let complete = vm.createCycleActionLog(for: habit, action: .complete, date: completeDate)
        #expect(complete != nil)
        vm.didFinishSaving()

        let skip = vm.createCycleActionLog(for: habit, action: .skip, date: skipDate)
        #expect(skip != nil)
        vm.didFinishSaving()

        let snooze = vm.createCycleActionLog(for: habit, action: .snooze, date: snoozeDate)
        #expect(snooze != nil)
        vm.didFinishSaving()

        complete?.habitDefinition = habit
        skip?.habitDefinition = habit
        snooze?.habitDefinition = habit
        habit.logs = [complete, skip, snooze].compactMap { $0 }

        let entries = vm.historyEntries(for: habit)
        #expect(entries.count == 3)
        #expect(entries.map(\.action) == [.snooze, .skip, .complete])
    }
}
