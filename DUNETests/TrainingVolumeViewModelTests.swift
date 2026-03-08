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

private struct MockTrainingVolumeHRVService: HRVQuerying {
    func fetchHRVSamples(days: Int) async throws -> [HRVSample] { [] }
    func fetchRestingHeartRate(for date: Date) async throws -> Double? { nil }
    func fetchLatestRestingHeartRate(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchHRVCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, average: Double)] { [] }
    func fetchRHRCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, min: Double, max: Double, average: Double)] { [] }
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
            stepsService: MockTrainingVolumeStepsService(),
            hrvService: MockTrainingVolumeHRVService()
        )

        await vm.loadData(manualRecords: [makeRecord(daysAgo: 1, minutes: 25)])

        #expect(vm.comparison != nil)
        #expect(vm.comparison!.current.totalSessions > 0)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("loadData falls back to manual records for training load history when workout fetch fails")
    func loadDataFallsBackToManualTrainingLoadHistory() async {
        let vm = TrainingVolumeViewModel(
            workoutService: MockTrainingVolumeWorkoutService(shouldThrow: true),
            stepsService: MockTrainingVolumeStepsService(),
            hrvService: MockTrainingVolumeHRVService()
        )

        await vm.loadData(manualRecords: [makeRecord(daysAgo: 1, minutes: 25)])

        #expect(vm.trainingLoadData.count == 14)
        #expect(vm.chartDailyBreakdown.count == 14)
        #expect(vm.trainingLoadData.contains { $0.load > 0 })
        #expect(vm.comparison != nil)
    }

    @Test("Changing selectedPeriod clears cached comparison")
    func selectedPeriodClearsComparison() {
        let vm = TrainingVolumeViewModel(
            workoutService: MockTrainingVolumeWorkoutService(),
            stepsService: MockTrainingVolumeStepsService(),
            hrvService: MockTrainingVolumeHRVService()
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
            stepsService: MockTrainingVolumeStepsService(),
            hrvService: MockTrainingVolumeHRVService()
        )
        vm.isLoading = true

        await vm.loadData(manualRecords: [])

        #expect(vm.isLoading == true)
        #expect(vm.comparison == nil)
    }

    @Test("loadData expands training load history to current and previous period") 
    func loadDataBuildsScrollableTrainingLoadHistory() async {
        let vm = TrainingVolumeViewModel(
            workoutService: MockTrainingVolumeWorkoutService(),
            stepsService: MockTrainingVolumeStepsService(),
            hrvService: MockTrainingVolumeHRVService()
        )
        vm.selectedPeriod = .month

        await vm.loadData(manualRecords: [])

        let today = calendar.startOfDay(for: Date())
        let expectedStart = calendar.date(byAdding: .day, value: -59, to: today) ?? today

        #expect(vm.trainingLoadData.count == 60)
        #expect(vm.trainingLoadData.first?.date == expectedStart)
        #expect(vm.trainingLoadData.last?.date == today)
    }

    @Test("loadData expands daily volume history to current and previous period")
    func loadDataBuildsScrollableDailyVolumeHistory() async {
        let vm = TrainingVolumeViewModel(
            workoutService: MockTrainingVolumeWorkoutService(),
            stepsService: MockTrainingVolumeStepsService(),
            hrvService: MockTrainingVolumeHRVService()
        )
        vm.selectedPeriod = .month

        await vm.loadData(manualRecords: [])

        let today = calendar.startOfDay(for: Date())
        let expectedStart = calendar.date(byAdding: .day, value: -59, to: today) ?? today

        #expect(vm.chartDailyBreakdown.count == 60)
        #expect(vm.chartDailyBreakdown.first?.date == expectedStart)
        #expect(vm.chartDailyBreakdown.last?.date == today)
    }
}
