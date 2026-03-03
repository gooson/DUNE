import Foundation
import Testing
@testable import DUNE

private enum TrainingVolumeViewModelTestError: Error {
    case failed
}

private struct MockTrainingVolumeWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []
    var shouldThrow = false

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        if shouldThrow { throw TrainingVolumeViewModelTestError.failed }
        return workouts
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        if shouldThrow { throw TrainingVolumeViewModelTestError.failed }
        return workouts
    }
}

private struct MockTrainingVolumeStepsService: StepsQuerying {
    func fetchSteps(for date: Date) async throws -> Double? { nil }
    func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchStepsCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, sum: Double)] { [] }
}

@Suite("TrainingVolumeViewModel")
@MainActor
struct TrainingVolumeViewModelTests {
    private let calendar = Calendar.current

    private func makeWorkout(id: String, daysAgo: Int, minutes: Double) -> WorkoutSummary {
        let today = calendar.startOfDay(for: Date())
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return WorkoutSummary(
            id: id,
            type: WorkoutActivityType.running.typeName,
            activityType: .running,
            duration: minutes * 60,
            calories: minutes * 8,
            distance: minutes * 100,
            date: date
        )
    }

    private func makeRecord(daysAgo: Int, minutes: Double) -> ExerciseRecord {
        let today = calendar.startOfDay(for: Date())
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        return ExerciseRecord(date: date, exerciseType: "Manual Squat", duration: minutes * 60)
    }

    private func makeSummary(period: VolumePeriod) -> VolumePeriodSummary {
        let now = Date()
        return VolumePeriodSummary(
            period: period,
            startDate: now,
            endDate: now,
            totalDuration: 600,
            totalCalories: 120,
            totalSessions: 2,
            activeDays: 2,
            exerciseTypes: [],
            dailyBreakdown: []
        )
    }

    @Test("loadData computes comparison from workouts and manual records")
    func loadDataBuildsComparison() async {
        let vm = TrainingVolumeViewModel(
            workoutService: MockTrainingVolumeWorkoutService(workouts: [
                makeWorkout(id: "run-1", daysAgo: 0, minutes: 40),
                makeWorkout(id: "run-2", daysAgo: 2, minutes: 30),
            ]),
            stepsService: MockTrainingVolumeStepsService()
        )

        await vm.loadData(manualRecords: [makeRecord(daysAgo: 1, minutes: 25)])

        #expect(vm.comparison != nil)
        #expect(vm.comparison!.current.totalSessions > 0)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("Changing selectedPeriod clears cached comparison")
    func selectedPeriodClearsComparison() {
        let vm = TrainingVolumeViewModel(
            workoutService: MockTrainingVolumeWorkoutService(),
            stepsService: MockTrainingVolumeStepsService()
        )

        vm.comparison = PeriodComparison(
            current: makeSummary(period: .week),
            previous: makeSummary(period: .week)
        )

        vm.selectedPeriod = .month

        #expect(vm.comparison == nil)
    }

    @Test("loadData returns immediately when already loading")
    func isLoadingGuard() async {
        let vm = TrainingVolumeViewModel(
            workoutService: MockTrainingVolumeWorkoutService(workouts: [makeWorkout(id: "run-1", daysAgo: 0, minutes: 30)]),
            stepsService: MockTrainingVolumeStepsService()
        )
        vm.isLoading = true

        await vm.loadData(manualRecords: [])

        #expect(vm.isLoading == true)
        #expect(vm.comparison == nil)
    }
}
