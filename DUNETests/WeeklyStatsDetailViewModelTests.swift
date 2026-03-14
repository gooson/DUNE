import Foundation
import Testing
@testable import DUNE

private enum WeeklyStatsViewModelTestError: Error {
    case failed
}

private struct MockWeeklyStatsWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []
    var shouldThrow = false

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        if shouldThrow { throw WeeklyStatsViewModelTestError.failed }
        return workouts
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        if shouldThrow { throw WeeklyStatsViewModelTestError.failed }
        return workouts
    }
}

private actor SequencedWeeklyStatsWorkoutService: WorkoutQuerying {
    private let firstWorkouts: [WorkoutSummary]
    private let secondWorkouts: [WorkoutSummary]
    private var fetchCount = 0
    private var didStartFirstFetch = false
    private var fetchStartedContinuation: CheckedContinuation<Void, Never>?
    private var fetchReleaseContinuation: CheckedContinuation<Void, Never>?

    init(firstWorkouts: [WorkoutSummary], secondWorkouts: [WorkoutSummary]) {
        self.firstWorkouts = firstWorkouts
        self.secondWorkouts = secondWorkouts
    }

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { [] }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        fetchCount += 1
        if fetchCount == 1 {
            didStartFirstFetch = true
            fetchStartedContinuation?.resume()
            fetchStartedContinuation = nil
            await withCheckedContinuation { continuation in
                fetchReleaseContinuation = continuation
            }
            return firstWorkouts
        }
        return secondWorkouts
    }

    func waitUntilFirstFetchStarts() async {
        if didStartFirstFetch { return }
        await withCheckedContinuation { continuation in
            fetchStartedContinuation = continuation
        }
    }

    func resumeFirstFetch() {
        fetchReleaseContinuation?.resume()
        fetchReleaseContinuation = nil
    }
}

@Suite("WeeklyStatsDetailViewModel")
@MainActor
struct WeeklyStatsDetailViewModelTests {
    private let calendar = Calendar.current

    private func day(_ daysAgo: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
    }

    private func makeWorkout(id: String, daysAgo: Int, minutes: Double) -> WorkoutSummary {
        WorkoutSummary(
            id: id,
            type: WorkoutActivityType.running.typeName,
            activityType: .running,
            duration: minutes * 60,
            calories: minutes * 7,
            distance: minutes * 90,
            date: day(daysAgo)
        )
    }

    private func makeManual(daysAgo: Int, minutes: Double) -> ManualExerciseSnapshot {
        ManualExerciseSnapshot(
            date: day(daysAgo),
            exerciseType: "Manual Squat",
            categoryRawValue: ActivityCategory.strength.rawValue,
            equipmentRawValue: Equipment.barbell.rawValue,
            duration: minutes * 60,
            calories: minutes * 5,
            totalVolume: 1_000
        )
    }

    @Test("loadData builds comparison and summary stats")
    func loadDataBuildsStats() async {
        let service = MockWeeklyStatsWorkoutService(workouts: [
            makeWorkout(id: "w1", daysAgo: 0, minutes: 30),
            makeWorkout(id: "w2", daysAgo: 2, minutes: 40),
        ])
        let vm = WeeklyStatsDetailViewModel(workoutService: service)

        await vm.loadData(manualSnapshots: [makeManual(daysAgo: 1, minutes: 20)])

        #expect(vm.comparison != nil)
        #expect(vm.summaryStats.count == 4)
        #expect(vm.summaryStats.contains { $0.id == "sessions" })
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("loadData falls back to manual snapshots when workout fetch fails")
    func loadDataFallsBackToManualSnapshotsWhenWorkoutFetchFails() async {
        let vm = WeeklyStatsDetailViewModel(
            workoutService: MockWeeklyStatsWorkoutService(shouldThrow: true)
        )

        await vm.loadData(manualSnapshots: [makeManual(daysAgo: 1, minutes: 20)])

        #expect(vm.comparison != nil)
        #expect(vm.chartDailyBreakdown.count == 28)
        #expect(vm.summaryStats.count == 4)
        #expect(vm.errorMessage == nil)
    }

    @Test("loadData builds scrollable chart history for this week")
    func loadDataBuildsChartHistory() async {
        let vm = WeeklyStatsDetailViewModel(workoutService: MockWeeklyStatsWorkoutService())

        await vm.loadData(manualSnapshots: [])

        let today = calendar.startOfDay(for: Date())
        let expectedStart = calendar.date(byAdding: .day, value: -27, to: today) ?? today

        #expect(vm.chartDailyBreakdown.count == 28)
        #expect(vm.chartDailyBreakdown.first?.date == expectedStart)
        #expect(vm.chartDailyBreakdown.last?.date == today)
    }

    @Test("lastWeek chart history anchors to the selected week end date")
    func lastWeekHistoryAnchorsToSelectedWeek() async {
        let vm = WeeklyStatsDetailViewModel(workoutService: MockWeeklyStatsWorkoutService())
        vm.selectedPeriod = .lastWeek

        await vm.loadData(manualSnapshots: [])

        let expectedEnd = calendar.startOfDay(for: vm.selectedPeriod.dateRange.end)
        let expectedStart = calendar.date(byAdding: .day, value: -27, to: expectedEnd) ?? expectedEnd

        #expect(vm.chartDailyBreakdown.count == 28)
        #expect(vm.chartDailyBreakdown.first?.date == expectedStart)
        #expect(vm.chartDailyBreakdown.last?.date == expectedEnd)
    }

    @Test("Changing selectedPeriod clears cached state")
    func selectedPeriodReset() {
        let vm = WeeklyStatsDetailViewModel(workoutService: MockWeeklyStatsWorkoutService())

        vm.chartDailyBreakdown = [DailyVolumePoint(date: Date(), segments: [])]
        vm.summaryStats = [.activeDays(value: "3")]
        vm.selectedPeriod = .thisMonth

        #expect(vm.comparison == nil)
        #expect(vm.chartDailyBreakdown.isEmpty)
        #expect(vm.summaryStats.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test("Service failure sets user-facing error")
    func loadFailure() async {
        let vm = WeeklyStatsDetailViewModel(
            workoutService: MockWeeklyStatsWorkoutService(shouldThrow: true)
        )

        await vm.loadData(manualSnapshots: [])

        #expect(vm.errorMessage != nil)
        #expect(vm.summaryStats.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test("newer period load keeps stale older response from overwriting chart history")
    func newerPeriodLoadWinsOverOlderResponse() async {
        let service = SequencedWeeklyStatsWorkoutService(
            firstWorkouts: [makeWorkout(id: "w1", daysAgo: 0, minutes: 30)],
            secondWorkouts: []
        )
        let vm = WeeklyStatsDetailViewModel(workoutService: service)

        let firstTask = Task {
            await vm.loadData(manualSnapshots: [])
        }

        await service.waitUntilFirstFetchStarts()
        vm.selectedPeriod = .thisMonth
        await vm.loadData(manualSnapshots: [])

        #expect(vm.chartDailyBreakdown.count == 60)

        await service.resumeFirstFetch()
        await firstTask.value

        #expect(vm.chartDailyBreakdown.count == 60)
        #expect(vm.isLoading == false)
    }
}
