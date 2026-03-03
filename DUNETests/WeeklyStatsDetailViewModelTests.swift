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

    @Test("Changing selectedPeriod clears cached state")
    func selectedPeriodReset() {
        let vm = WeeklyStatsDetailViewModel(workoutService: MockWeeklyStatsWorkoutService())

        vm.summaryStats = [.activeDays(value: "3")]
        vm.selectedPeriod = .thisMonth

        #expect(vm.comparison == nil)
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
}
