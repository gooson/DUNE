import Foundation
import Testing
@testable import DUNE

@Suite("Life log replacement")
@MainActor
struct LifeLogReplacementTests {
    private let calendar = Calendar.current

    private func day(_ offset: Int, from referenceDate: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: referenceDate))!
    }

    private func habit(
        type: HabitType = .count,
        frequency: HabitFrequency = .daily,
        createdAt: Date
    ) -> HabitDefinition {
        let habit = HabitDefinition(
            name: "Practice",
            iconCategory: .health,
            habitType: type,
            goalValue: type == .check ? 1 : 5,
            goalUnit: nil,
            frequency: frequency
        )
        habit.createdAt = createdAt
        habit.recurringStartConfiguredAt = createdAt
        return habit
    }

    @Test("Invalid total preserves existing logs and save state")
    func invalidTotalPreservesExistingLogs() {
        let now = Date()
        let yesterday = day(-1, from: now)
        let habit = habit(createdAt: day(-10, from: now))
        let existing = HabitLog(date: yesterday, value: 3)
        habit.logs = [existing]
        let vm = LifeViewModel()

        #expect(vm.prepareLogReplacement(for: habit, value: 1000, date: yesterday, referenceDate: now, isPastEntry: true) == nil)
        #expect(habit.logs?.count == 1)
        #expect(habit.logs?.first?.id == existing.id)
        #expect(!vm.isSaving)
        #expect(vm.validationError != nil)
    }

    @Test("NaN and infinity are rejected before any replacement")
    func nonfiniteValues() {
        let now = Date()
        let habit = habit(createdAt: day(-10, from: now))
        let vm = LifeViewModel()

        for value in [Double.nan, Double.infinity, -Double.infinity] {
            #expect(vm.prepareLogReplacement(for: habit, value: value, referenceDate: now) == nil)
            #expect(!vm.isSaving)
        }
    }

    @Test("Zero prepares deletion for check, count, and duration")
    func zeroClearsManualLogs() {
        let now = Date()
        let yesterday = day(-1, from: now)
        for type in HabitType.allCases {
            let habit = habit(type: type, createdAt: day(-10, from: now))
            let manual = HabitLog(date: yesterday, value: 1)
            habit.logs = [manual]
            let vm = LifeViewModel()

            let plan = vm.prepareLogReplacement(for: habit, value: 0, date: yesterday, referenceDate: now, isPastEntry: true)
            #expect(plan?.existingLogs.map(\.id) == [manual.id])
            #expect(plan?.newLog == nil)
            #expect(vm.isSaving)
            vm.didFinishSaving()
        }
    }

    @Test("Same day manual duplicates and scheduling actions are replaced, auto logs remain")
    func sameDayDuplicates() {
        let now = Date()
        let yesterday = day(-1, from: now)
        let habit = habit(type: .check, frequency: .interval(days: 7), createdAt: day(-20, from: now))
        let first = HabitLog(date: yesterday, value: 1)
        let second = HabitLog(date: yesterday, value: 0, memo: "[dune-life-cycle-skip]")
        let auto = HabitLog(date: yesterday, value: 1, isAutoCompleted: true)
        let otherDay = HabitLog(date: day(-2, from: now), value: 1)
        habit.logs = [first, second, auto, otherDay]
        let vm = LifeViewModel()

        let plan = vm.prepareLogReplacement(for: habit, value: 1, date: yesterday, referenceDate: now, isPastEntry: true)
        #expect(Set(plan?.existingLogs.map(\.id) ?? []) == Set([first.id, second.id]))
        #expect(plan?.newLog?.date == yesterday)
        #expect(plan?.newLog?.completedAt == now)
        #expect(habit.logs?.count == 4)
        vm.didFinishSaving()
    }

    @Test("Past entry rejects today, future, precreation, and preconfiguration dates")
    func dateBounds() {
        let now = Date()
        let habit = habit(type: .check, frequency: .interval(days: 7), createdAt: day(-10, from: now))
        habit.recurringStartConfiguredAt = day(-5, from: now)
        let vm = LifeViewModel()

        for date in [day(-11, from: now), day(-6, from: now), day(0, from: now), day(1, from: now)] {
            #expect(vm.prepareLogReplacement(for: habit, value: 1, date: date, referenceDate: now, isPastEntry: true) == nil)
            #expect(!vm.isSaving)
        }
        let plan = vm.prepareLogReplacement(for: habit, value: 1, date: day(-5, from: now), referenceDate: now, isPastEntry: true)
        #expect(plan?.newLog != nil)
        vm.didFinishSaving()
    }

    @Test("Archived and auto linked habits are not manually replaced")
    func ineligibleHabits() {
        let now = Date()
        let habit = habit(createdAt: day(-10, from: now))
        let vm = LifeViewModel()
        habit.isAutoLinked = true
        #expect(vm.prepareLogReplacement(for: habit, value: 1, referenceDate: now) == nil)
        habit.isAutoLinked = false
        habit.isArchived = true
        #expect(vm.prepareLogReplacement(for: habit, value: 1, referenceDate: now) == nil)
        #expect(!vm.isSaving)
    }

    @Test("Weekly and recurring logs remain untouched until caller applies the plan")
    func scheduleContracts() {
        let now = Date()
        let older = day(-8, from: now)
        let recent = day(-1, from: now)
        for frequency in [HabitFrequency.weekly(targetDays: 3), .interval(days: 7)] {
            let habit = habit(type: .check, frequency: frequency, createdAt: day(-20, from: now))
            let oldLog = HabitLog(date: older, value: 1)
            let latestLog = HabitLog(date: recent, value: 1)
            habit.logs = [oldLog, latestLog]
            let vm = LifeViewModel()
            let beforeCycle = vm.cycleSnapshot(for: habit, referenceDate: now)?.nextDueDate

            let plan = vm.prepareLogReplacement(for: habit, value: 0, date: older, referenceDate: now, isPastEntry: true)
            #expect(plan?.existingLogs.map(\.id) == [oldLog.id])
            #expect(plan?.newLog == nil)
            #expect(habit.logs?.map(\.id) == [oldLog.id, latestLog.id])
            #expect(vm.cycleSnapshot(for: habit, referenceDate: now)?.nextDueDate == beforeCycle)
            vm.didFinishSaving()
        }
    }

    @Test("Preview keeps the newest completion as the recurring anchor")
    func previewKeepsNewestCompletion() {
        let now = Date()
        let habit = habit(type: .check, frequency: .interval(days: 7), createdAt: day(-30, from: now))
        let older = HabitLog(date: day(-15, from: now), value: 1)
        let latest = HabitLog(date: day(-2, from: now), value: 1)
        habit.logs = [older, latest]
        let vm = LifeViewModel()

        let preview = vm.previewPastRecordNextDueDate(
            for: habit,
            value: 1,
            date: day(-15, from: now),
            referenceDate: now
        )

        #expect(preview == day(5, from: now))
        #expect(habit.logs?.map(\.id) == [older.id, latest.id])
        #expect(!vm.isSaving)
    }

    @Test("Preview replays later skip and snooze events without changing logs")
    func previewReplaysLaterActions() {
        let now = Date()
        let habit = habit(type: .check, frequency: .interval(days: 2), createdAt: day(-30, from: now))
        let old = HabitLog(date: day(-10, from: now), value: 1)
        let skip = HabitLog(date: day(-5, from: now), value: 0, memo: "[dune-life-cycle-skip]")
        let snooze = HabitLog(date: day(-1, from: now), value: 0, memo: "[dune-life-cycle-snooze]")
        habit.logs = [old, skip, snooze]
        let vm = LifeViewModel()

        let preview = vm.previewPastRecordNextDueDate(
            for: habit,
            value: 1,
            date: day(-10, from: now),
            referenceDate: now
        )

        #expect(preview == day(-1, from: now))
        #expect(habit.logs?.map(\.id) == [old.id, skip.id, snooze.id])
        #expect(!vm.isSaving)
    }

    @Test("Preview of zero clears the selected completion only in its temporary log list")
    func previewClear() {
        let now = Date()
        let habit = habit(type: .check, frequency: .interval(days: 7), createdAt: day(-30, from: now))
        let old = HabitLog(date: day(-8, from: now), value: 1)
        habit.logs = [old]
        let vm = LifeViewModel()

        let preview = vm.previewPastRecordNextDueDate(
            for: habit,
            value: 0,
            date: day(-8, from: now),
            referenceDate: now
        )

        #expect(preview == day(-23, from: now))
        #expect(habit.logs?.map(\.id) == [old.id])
        #expect(!vm.isSaving)
    }
}
