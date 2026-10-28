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
            #expect(plan?.newLog?.value == 0)
            #expect(plan?.newLog?.memo == HabitLogResolution.dailyTotalMemo)
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
            #expect(plan?.newLog?.value == 0)
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

    @Test("Latest synced daily total wins instead of adding concurrent totals")
    func concurrentTotalsResolve() {
        let now = Date()
        let habit = habit(createdAt: day(-10, from: now))
        let date = day(-1, from: now)
        let earlier = HabitLog(date: date, value: 8, completedAt: now.addingTimeInterval(-60), memo: HabitLogResolution.dailyTotalMemo)
        let later = HabitLog(date: date, value: 5, completedAt: now, memo: HabitLogResolution.dailyTotalMemo)
        let oldIncrement = HabitLog(date: date, value: 3, completedAt: now.addingTimeInterval(-120))
        habit.logs = [earlier, later, oldIncrement]

        let resolved = HabitLogResolution.resolve(habit.logs ?? [], habitID: habit.id)
        #expect(resolved.map(\.id) == [later.id])
        #expect(resolved.reduce(0) { $0 + $1.value } == 5)
    }

    @Test("Equal completed timestamps use a stable UUID tie breaker")
    func sameTimestampTie() {
        let now = Date()
        let habit = habit(createdAt: day(-10, from: now))
        let date = day(-1, from: now)
        let first = HabitLog(date: date, value: 8, completedAt: now, memo: HabitLogResolution.dailyTotalMemo)
        let second = HabitLog(date: date, value: 5, completedAt: now, memo: HabitLogResolution.dailyTotalMemo)
        let expected = first.id.uuidString > second.id.uuidString ? first.id : second.id

        #expect(HabitLogResolution.resolve([first, second], habitID: habit.id).map(\.id) == [expected])
        #expect(HabitLogResolution.resolve([second, first], habitID: habit.id).map(\.id) == [expected])
    }

    @Test("Zero total tombstone suppresses older increments but keeps auto logs")
    func zeroTombstoneResolution() {
        let now = Date()
        let habit = habit(createdAt: day(-10, from: now))
        let date = day(-1, from: now)
        let old = HabitLog(date: date, value: 3, completedAt: now.addingTimeInterval(-60))
        let zero = HabitLog(date: date, value: 0, completedAt: now, memo: HabitLogResolution.dailyTotalMemo)
        let auto = HabitLog(date: date, value: 2, isAutoCompleted: true)

        let resolved = HabitLogResolution.resolve([old, zero, auto], habitID: habit.id)
        #expect(Set(resolved.map(\.id)) == Set([zero.id, auto.id]))
        #expect(!resolved.contains { $0.id == old.id })
    }

    @Test("Legacy manual increments remain additive without a marked total")
    func legacyIncrementsRemainAdditive() {
        let now = Date()
        let habit = habit(createdAt: day(-10, from: now))
        let date = day(-1, from: now)
        let first = HabitLog(date: date, value: 2)
        let second = HabitLog(date: date, value: 3)

        let resolved = HabitLogResolution.resolve([first, second], habitID: habit.id)
        #expect(resolved.count == 2)
        #expect(resolved.reduce(0) { $0 + $1.value } == 5)
    }

    @Test("Independent log query supplies missing relationship logs for replacement")
    func additionalLogsFillRelationshipGap() {
        let now = Date()
        let date = day(-1, from: now)
        let habit = habit(createdAt: day(-10, from: now))
        let queried = HabitLog(date: date, value: 3)
        let queryOwner = self.habit(createdAt: day(-10, from: now))
        queryOwner.id = habit.id
        queried.habitDefinition = queryOwner
        habit.logs = nil
        let vm = LifeViewModel()

        let plan = vm.prepareLogReplacement(
            for: habit,
            value: 8,
            date: date,
            referenceDate: now,
            isPastEntry: true,
            additionalLogs: [queried]
        )

        #expect(plan?.existingLogs.map(\.id) == [queried.id])
        #expect(plan?.newLog?.value == 8)
        vm.didFinishSaving()
    }

    @Test("A later explicit cycle action survives a same-day total")
    func laterCycleActionSurvives() {
        let now = Date()
        let date = day(-1, from: now)
        let habit = habit(type: .check, frequency: .interval(days: 7), createdAt: day(-20, from: now))
        let total = HabitLog(date: date, value: 1, completedAt: now.addingTimeInterval(-60), memo: HabitLogResolution.dailyTotalMemo)
        let skip = HabitLog(date: date, value: 0, completedAt: now, memo: "[dune-life-cycle-skip]")

        let resolved = HabitLogResolution.resolve([skip, total], habitID: habit.id)
        #expect(Set(resolved.map(\.id)) == Set([total.id, skip.id]))
    }

    @Test("A zero total does not start a first-completion cycle")
    func zeroDoesNotStartFirstCompletionCycle() {
        let now = Date()
        let habit = habit(type: .check, frequency: .interval(days: 7), createdAt: day(-20, from: now))
        habit.recurringStartPointRaw = HabitRecurringStartPoint.firstCompletion.rawValue
        let old = HabitLog(date: day(-8, from: now), value: 1, completedAt: now.addingTimeInterval(-60))
        let zero = HabitLog(date: day(-8, from: now), value: 0, completedAt: now, memo: HabitLogResolution.dailyTotalMemo)
        habit.logs = [old, zero]
        let vm = LifeViewModel()

        let snapshot = vm.cycleSnapshot(for: habit, referenceDate: now)
        #expect(snapshot?.startDate == nil)
        #expect(snapshot?.lastCompletedAt == nil)
        #expect(snapshot?.nextDueDate == nil)
        #expect(vm.historyEntries(for: habit).isEmpty)
    }

    @Test("Cycle replay orders same-day actions by completion time")
    func stableCycleOrdering() {
        let now = Date()
        let habit = habit(type: .check, frequency: .interval(days: 7), createdAt: day(-20, from: now))
        let date = day(-1, from: now)
        let complete = HabitLog(date: date, value: 1, completedAt: now.addingTimeInterval(-60))
        let skip = HabitLog(date: date, value: 0, completedAt: now, memo: "[dune-life-cycle-skip]")
        let vm = LifeViewModel()

        habit.logs = [complete, skip]
        let first = vm.cycleSnapshot(for: habit, referenceDate: now)
        habit.logs = [skip, complete]
        let second = vm.cycleSnapshot(for: habit, referenceDate: now)

        #expect(first?.lastAction == .skip)
        #expect(second?.lastAction == .skip)
        #expect(first?.nextDueDate == second?.nextDueDate)
    }
    @Test("Independent query logs drive progress, history, streak, and cycle consistently")
    func queryLogsDriveAllReadPaths() {
        let now = Date()
        let daily = habit(createdAt: day(-10, from: now))
        let todayLog = HabitLog(date: now, value: 5, completedAt: now, memo: HabitLogResolution.dailyTotalMemo)
        let queryOwner = habit(createdAt: day(-10, from: now))
        queryOwner.id = daily.id
        todayLog.habitDefinition = queryOwner
        daily.logs = nil
        let vm = LifeViewModel()
        vm.calculateProgresses(habits: [daily], todayExerciseExists: false, referenceDate: now, additionalLogs: [todayLog])
        #expect(vm.completedCount == 1)
        #expect(vm.habitProgresses.first?.todayValue == 5)
        #expect(vm.habitProgresses.first?.streak == 1)
        #expect(vm.historyEntries(for: daily, additionalLogs: [todayLog]).map(\.id) == [todayLog.id])

        let recurring = habit(type: .check, frequency: .interval(days: 7), createdAt: day(-30, from: now))
        let past = HabitLog(date: day(-1, from: now), value: 1, completedAt: now)
        let cycleOwner = habit(type: .check, frequency: .interval(days: 7), createdAt: day(-30, from: now))
        cycleOwner.id = recurring.id
        past.habitDefinition = cycleOwner
        recurring.logs = nil
        let cycle = vm.cycleSnapshot(for: recurring, referenceDate: now, additionalLogs: [past])
        #expect(cycle?.nextDueDate == day(6, from: now))
        #expect(cycle?.historyCount == 1)
    }

}
