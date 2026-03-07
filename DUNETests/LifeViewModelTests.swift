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
        #expect(habit?.recurringStartPoint == .createdAt)
        #expect(habit?.recurringCustomStartDate == nil)
        vm.didFinishSaving()
    }

    @Test("createValidatedHabit stores custom recurring start date")
    func intervalCustomStartDate() {
        let vm = LifeViewModel()
        let calendar = Calendar.current
        let customStart = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_712_966_400)) // 2024-04-12

        vm.name = "Seasonal maintenance"
        vm.selectedType = .check
        vm.frequencyType = "interval"
        vm.intervalDays = 30
        vm.intervalStartPoint = .customDate
        vm.intervalCustomStartDate = customStart

        let habit = vm.createValidatedHabit()
        #expect(habit != nil)
        #expect(habit?.recurringStartPoint == .customDate)
        #expect(habit?.recurringCustomStartDate == customStart)
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
        #expect(vm.intervalStartPoint == .createdAt)
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
        habit.recurringStartConfiguredAt = createdAt

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
        #expect(snapshot?.canComplete == false)
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
        habit.recurringStartConfiguredAt = createdAt

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

    @Test("cycle snapshot is scheduled when custom start date is in the future")
    func cycleSnapshotFutureCustomStart() {
        let vm = LifeViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let futureStart = calendar.date(byAdding: .day, value: 5, to: today)!
        let expectedDue = calendar.date(byAdding: .day, value: 7, to: futureStart)!

        let habit = HabitDefinition(
            name: "Window cleaning",
            iconCategory: .chores,
            habitType: .check,
            goalValue: 1,
            goalUnit: nil,
            frequency: .interval(days: 7),
            recurringStartPoint: .customDate,
            recurringCustomStartDate: futureStart,
            recurringStartConfiguredAt: today
        )

        let snapshot = vm.cycleSnapshot(for: habit, referenceDate: today)
        #expect(snapshot != nil)
        #expect(snapshot?.isScheduled == true)
        #expect(snapshot?.startDate == futureStart)
        #expect(snapshot?.nextDueDate == expectedDue)
        #expect(snapshot?.canComplete == false)
        #expect(snapshot?.isDue == false)
    }

    @Test("cycle snapshot waits for first completion when start point is first completion")
    func cycleSnapshotFirstCompletionWaits() {
        let vm = LifeViewModel()

        let habit = HabitDefinition(
            name: "Haircut",
            iconCategory: .chores,
            habitType: .check,
            goalValue: 1,
            goalUnit: nil,
            frequency: .interval(days: 30),
            recurringStartPoint: .firstCompletion
        )

        let snapshot = vm.cycleSnapshot(for: habit)
        #expect(snapshot != nil)
        #expect(snapshot?.isScheduled == true)
        #expect(snapshot?.startPoint == .firstCompletion)
        #expect(snapshot?.startDate == nil)
        #expect(snapshot?.nextDueDate == nil)
        #expect(snapshot?.canComplete == true)
    }

    @Test("cycle snapshot allows completion before due date")
    func cycleSnapshotCanCompleteBeforeDue() {
        let vm = LifeViewModel()
        let calendar = Calendar.current
        let createdAt = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_704_067_200)) // 2024-01-01
        let referenceDate = calendar.date(byAdding: .day, value: 3, to: createdAt)!
        let expectedDue = calendar.date(byAdding: .day, value: 7, to: createdAt)!

        let habit = HabitDefinition(
            name: "Laundry",
            iconCategory: .chores,
            habitType: .check,
            goalValue: 1,
            goalUnit: nil,
            frequency: .interval(days: 7)
        )
        habit.createdAt = createdAt
        habit.recurringStartConfiguredAt = createdAt

        let snapshot = vm.cycleSnapshot(for: habit, referenceDate: referenceDate)
        #expect(snapshot != nil)
        #expect(snapshot?.nextDueDate == expectedDue)
        #expect(snapshot?.canComplete == true)
        #expect(snapshot?.isDue == false)
    }

    @Test("cycle snapshot blocks repeat completion before next due after completion")
    func cycleSnapshotBlocksRepeatCompletionBeforeDue() {
        let vm = LifeViewModel()
        let calendar = Calendar.current
        let createdAt = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_704_067_200)) // 2024-01-01
        let completedAt = calendar.date(byAdding: .day, value: 2, to: createdAt)!
        let referenceDate = calendar.date(byAdding: .day, value: 3, to: createdAt)!
        let expectedDue = calendar.date(byAdding: .day, value: 9, to: createdAt)!

        let habit = HabitDefinition(
            name: "Filter",
            iconCategory: .chores,
            habitType: .check,
            goalValue: 1,
            goalUnit: nil,
            frequency: .interval(days: 7)
        )
        habit.createdAt = createdAt
        habit.recurringStartConfiguredAt = createdAt

        let completion = vm.createCycleActionLog(for: habit, action: .complete, date: completedAt)
        #expect(completion != nil)
        vm.didFinishSaving()

        completion?.habitDefinition = habit
        habit.logs = [completion].compactMap { $0 }

        let snapshot = vm.cycleSnapshot(for: habit, referenceDate: referenceDate)
        #expect(snapshot != nil)
        #expect(snapshot?.nextDueDate == expectedDue)
        #expect(snapshot?.canComplete == false)
        #expect(snapshot?.isDue == false)
        #expect(snapshot?.lastAction == .complete)
    }

    @Test("applyUpdate changes recurring start point forward only")
    func applyUpdateRecurringStartPointForwardOnly() {
        let vm = LifeViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let oldCompletionDate = calendar.date(byAdding: .day, value: -20, to: today)!
        let customStart = calendar.date(byAdding: .day, value: 2, to: today)!

        let habit = HabitDefinition(
            name: "Filter",
            iconCategory: .chores,
            habitType: .check,
            goalValue: 1,
            goalUnit: nil,
            frequency: .interval(days: 7)
        )

        let oldLog = HabitLog(date: oldCompletionDate, value: 1)
        oldLog.habitDefinition = habit
        habit.logs = [oldLog]

        vm.startEditing(habit)
        vm.frequencyType = "interval"
        vm.intervalStartPoint = .customDate
        vm.intervalCustomStartDate = customStart

        let updated = vm.applyUpdate(to: habit)
        #expect(updated == true)
        vm.didFinishSaving()

        let snapshot = vm.cycleSnapshot(for: habit, referenceDate: today)
        #expect(snapshot != nil)
        #expect(snapshot?.isScheduled == true)
        #expect(snapshot?.startDate == customStart)
        #expect(snapshot?.historyCount == 0)
    }

    // MARK: - heroNarrative

    @Test("heroNarrative shows waiting message when none completed")
    func heroNarrativeNoneCompleted() {
        let vm = LifeViewModel()
        let habits = [
            HabitDefinition(name: "A", iconCategory: .health, habitType: .check, goalValue: 1, goalUnit: nil, frequency: .daily),
            HabitDefinition(name: "B", iconCategory: .health, habitType: .check, goalValue: 1, goalUnit: nil, frequency: .daily)
        ]
        vm.calculateProgresses(habits: habits, todayExerciseExists: false)
        #expect(vm.completedCount == 0)
        #expect(!vm.heroNarrative.isEmpty)
        #expect(vm.heroNarrative.contains("2"))
    }

    @Test("heroNarrative shows partial completion message")
    func heroNarrativePartial() {
        let vm = LifeViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let habit1 = HabitDefinition(name: "A", iconCategory: .health, habitType: .check, goalValue: 1, goalUnit: nil, frequency: .daily)
        let habit2 = HabitDefinition(name: "B", iconCategory: .health, habitType: .check, goalValue: 1, goalUnit: nil, frequency: .daily)
        let log = HabitLog(date: today, value: 1)
        log.habitDefinition = habit1
        habit1.logs = [log]

        vm.calculateProgresses(habits: [habit1, habit2], todayExerciseExists: false)
        #expect(vm.completedCount == 1)
        #expect(vm.totalActiveCount == 2)
        #expect(vm.heroNarrative.contains("1") && vm.heroNarrative.contains("2"))
    }

    @Test("heroNarrative shows all done message")
    func heroNarrativeAllDone() {
        let vm = LifeViewModel()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let habit = HabitDefinition(name: "A", iconCategory: .health, habitType: .check, goalValue: 1, goalUnit: nil, frequency: .daily)
        let log = HabitLog(date: today, value: 1)
        log.habitDefinition = habit
        habit.logs = [log]

        vm.calculateProgresses(habits: [habit], todayExerciseExists: false)
        #expect(vm.completedCount == 1)
        #expect(vm.totalActiveCount == 1)
        #expect(!vm.heroNarrative.isEmpty)
    }

    @Test("heroNarrative shows add habits message when no habits")
    func heroNarrativeNoHabits() {
        let vm = LifeViewModel()
        vm.calculateProgresses(habits: [], todayExerciseExists: false)
        #expect(vm.totalActiveCount == 0)
        #expect(!vm.heroNarrative.isEmpty)
    }

    // MARK: - Auto Achievements

    @Test("calculateAutoExerciseProgresses updates auto achievement list")
    func autoAchievementCalculation() {
        let vm = LifeViewModel()
        let record = ExerciseRecord(
            date: Date(),
            exerciseType: "running",
            duration: 1200,
            distance: 5,
            isFromHealthKit: true,
            healthKitWorkoutID: "hk-auto-1",
            exerciseDefinitionID: "running"
        )

        vm.calculateAutoExerciseProgresses(exerciseRecords: [record])

        #expect(vm.autoExerciseProgresses.isEmpty == false)
        let weekly5 = vm.autoExerciseProgresses.first { $0.id == "weeklyWorkout5" }
        #expect(weekly5?.currentValue == 1)
    }

    @Test("LifeHabitLogSync insert updates relationship immediately")
    func lifeHabitLogSyncInsert() {
        let habit = HabitDefinition(
            name: "Morning Stretch",
            iconCategory: .fitness,
            habitType: .check,
            goalValue: 1,
            goalUnit: nil,
            frequency: .daily
        )
        let log = HabitLog(date: Date(), value: 1)

        LifeHabitLogSync.insert(log, into: habit)

        #expect(log.habitDefinition === habit)
        #expect(habit.logs?.count == 1)
        #expect(habit.logs?.first?.id == log.id)
    }

    @Test("LifeHabitLogSync delete removes matching logs from relationship")
    func lifeHabitLogSyncDelete() {
        let habit = HabitDefinition(
            name: "Morning Stretch",
            iconCategory: .fitness,
            habitType: .check,
            goalValue: 1,
            goalUnit: nil,
            frequency: .daily
        )
        let keep = HabitLog(date: Date(), value: 1)
        let remove = HabitLog(date: Date(), value: 1)

        LifeHabitLogSync.insert(keep, into: habit)
        LifeHabitLogSync.insert(remove, into: habit)

        LifeHabitLogSync.delete([remove], from: habit)

        #expect(habit.logs?.count == 1)
        #expect(habit.logs?.first?.id == keep.id)
    }
}
