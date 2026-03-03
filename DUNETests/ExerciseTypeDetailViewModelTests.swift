import Foundation
import Testing
@testable import DUNE

private struct MockExerciseTypeWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] { workouts }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] { workouts }
}

@Suite("ExerciseTypeDetailViewModel")
@MainActor
struct ExerciseTypeDetailViewModelTests {
    private let calendar = Calendar.current

    private func makeWorkout(id: String, type: WorkoutActivityType, daysAgo: Int, durationMinutes: Double) -> WorkoutSummary {
        let base = calendar.startOfDay(for: Date())
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: base) ?? base
        return WorkoutSummary(
            id: id,
            type: type.typeName,
            activityType: type,
            duration: durationMinutes * 60.0,
            calories: durationMinutes * 8,
            distance: type.isDistanceBased ? durationMinutes * 100 : nil,
            date: date
        )
    }

    private func makeSummary(typeKey: String, duration: TimeInterval, calories: Double) -> ExerciseTypeVolume {
        ExerciseTypeVolume(
            typeKey: typeKey,
            displayName: "Running",
            categoryRawValue: ActivityCategory.cardio.rawValue,
            equipmentRawValue: nil,
            totalDuration: duration,
            totalCalories: calories,
            sessionCount: 2,
            totalDistance: 10_000,
            totalVolume: nil
        )
    }

    @Test("loadData filters workouts by typeKey and builds trend/recent lists")
    func loadDataFiltersByType() async {
        let service = MockExerciseTypeWorkoutService(workouts: [
            makeWorkout(id: "run-1", type: .running, daysAgo: 0, durationMinutes: 45),
            makeWorkout(id: "run-2", type: .running, daysAgo: 2, durationMinutes: 30),
            makeWorkout(id: "walk-1", type: .walking, daysAgo: 1, durationMinutes: 20),
        ])
        let vm = ExerciseTypeDetailViewModel(
            typeKey: WorkoutActivityType.running.rawValue,
            displayName: "Running",
            workoutService: service
        )

        await vm.loadData(manualRecords: [])

        #expect(vm.currentSummary != nil)
        #expect(vm.recentWorkouts.count == 2)
        #expect(vm.recentWorkouts.allSatisfy { $0.activityType == .running })
        #expect(!vm.trendData.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test("selectedPeriod change clears cached detail data")
    func selectedPeriodResetsState() {
        let vm = ExerciseTypeDetailViewModel(
            typeKey: WorkoutActivityType.running.rawValue,
            displayName: "Running",
            workoutService: MockExerciseTypeWorkoutService()
        )

        vm.currentSummary = makeSummary(typeKey: WorkoutActivityType.running.rawValue, duration: 1_800, calories: 300)
        vm.previousSummary = makeSummary(typeKey: WorkoutActivityType.running.rawValue, duration: 1_200, calories: 200)
        vm.trendData = [ChartDataPoint(date: Date(), value: 20)]

        vm.selectedPeriod = .month

        #expect(vm.currentSummary == nil)
        #expect(vm.previousSummary == nil)
        #expect(vm.trendData.isEmpty)
    }

    @Test("durationChange and calorieChange return nil when previous baseline is zero")
    func changeRequiresNonZeroPrevious() {
        let vm = ExerciseTypeDetailViewModel(
            typeKey: WorkoutActivityType.running.rawValue,
            displayName: "Running",
            workoutService: MockExerciseTypeWorkoutService()
        )

        vm.currentSummary = makeSummary(typeKey: WorkoutActivityType.running.rawValue, duration: 2_400, calories: 400)
        vm.previousSummary = makeSummary(typeKey: WorkoutActivityType.running.rawValue, duration: 0, calories: 0)

        #expect(vm.durationChange == nil)
        #expect(vm.calorieChange == nil)
    }

    @Test("durationChange and calorieChange compute finite percentages")
    func changeComputed() {
        let vm = ExerciseTypeDetailViewModel(
            typeKey: WorkoutActivityType.running.rawValue,
            displayName: "Running",
            workoutService: MockExerciseTypeWorkoutService()
        )

        vm.currentSummary = makeSummary(typeKey: WorkoutActivityType.running.rawValue, duration: 2_400, calories: 450)
        vm.previousSummary = makeSummary(typeKey: WorkoutActivityType.running.rawValue, duration: 1_200, calories: 300)

        #expect(vm.durationChange != nil)
        #expect(vm.calorieChange != nil)
        #expect(vm.durationChange! > 0)
        #expect(vm.calorieChange! > 0)
    }
}
