import Testing
import Foundation
@testable import Dailve

// MARK: - Mock Services for ActivityViewModel

private struct MockWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []
    var shouldThrow = false

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        if shouldThrow { throw TestError.mockFailure }
        return workouts
    }
    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        if shouldThrow { throw TestError.mockFailure }
        return workouts
    }
}

private struct MockStepsService: StepsQuerying {
    var stepsCollection: [(date: Date, sum: Double)] = []
    var shouldThrow = false

    func fetchSteps(for date: Date) async throws -> Double? { nil }
    func fetchLatestSteps(withinDays days: Int) async throws -> (value: Double, date: Date)? { nil }
    func fetchStepsCollection(start: Date, end: Date, interval: DateComponents) async throws -> [(date: Date, sum: Double)] {
        if shouldThrow { throw TestError.mockFailure }
        return stepsCollection
    }
}

private enum TestError: Error {
    case mockFailure
}

// MARK: - Tests

@Suite("ActivityViewModel")
@MainActor
struct ActivityViewModelTests {

    private let calendar = Calendar.current

    // MARK: - Parallel Loading

    @Test("loads exercise, steps, and workouts in parallel")
    func parallelLoading() async {
        let today = calendar.startOfDay(for: Date())

        let workouts = MockWorkoutService(workouts: [
            WorkoutSummary(id: "1", type: "Running", duration: 1800, calories: 200, distance: 5000, date: today),
        ])
        let steps = MockStepsService(stepsCollection: [
            (date: today, sum: 8500),
        ])

        let vm = ActivityViewModel(workoutService: workouts, stepsService: steps)
        await vm.loadActivityData()

        #expect(vm.todayExercise != nil)
        #expect(vm.todayExercise!.value == 30.0) // 1800/60
        #expect(vm.todaySteps != nil)
        #expect(vm.todaySteps!.value == 8500.0)
        #expect(vm.recentWorkouts.count == 1)
        #expect(vm.isLoading == false)
    }

    // MARK: - Weekly Data Gap Fill

    @Test("weekly data fills gaps with zero")
    func weeklyGapFill() async {
        let today = calendar.startOfDay(for: Date())
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let steps = MockStepsService(stepsCollection: [
            (date: twoDaysAgo, sum: 10000),
            (date: today, sum: 5000),
        ])

        let vm = ActivityViewModel(workoutService: MockWorkoutService(), stepsService: steps)
        await vm.loadActivityData()

        // Should have 7 data points (filling gaps with 0)
        #expect(vm.weeklySteps.count == 7)

        // At least one zero-filled day
        let zeroDays = vm.weeklySteps.filter { $0.value == 0 }
        #expect(zeroDays.count >= 4) // 7 total - at most 3 with data
    }

    @Test("weekly exercise fills gaps with zero")
    func weeklyExerciseGapFill() async {
        let today = calendar.startOfDay(for: Date())

        let workouts = MockWorkoutService(workouts: [
            WorkoutSummary(id: "1", type: "Running", duration: 3600, calories: nil, distance: nil, date: today),
        ])

        let vm = ActivityViewModel(workoutService: workouts, stepsService: MockStepsService())
        await vm.loadActivityData()

        #expect(vm.weeklyExerciseMinutes.count == 7)
        let nonZero = vm.weeklyExerciseMinutes.filter { $0.value > 0 }
        #expect(nonZero.count == 1)
        #expect(nonZero.first!.value == 60.0)
    }

    // MARK: - Fallback / Error Handling

    @Test("gracefully handles workout service failure")
    func workoutFailure() async {
        let workouts = MockWorkoutService(shouldThrow: true)
        let steps = MockStepsService(stepsCollection: [
            (date: calendar.startOfDay(for: Date()), sum: 5000),
        ])

        let vm = ActivityViewModel(workoutService: workouts, stepsService: steps)
        await vm.loadActivityData()

        // Steps should still load even if workouts fail
        #expect(vm.todaySteps != nil)
        #expect(vm.todaySteps!.value == 5000.0)
        // Exercise falls back to empty
        #expect(vm.weeklyExerciseMinutes.isEmpty)
        #expect(vm.recentWorkouts.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test("gracefully handles steps service failure")
    func stepsFailure() async {
        let today = calendar.startOfDay(for: Date())
        let workouts = MockWorkoutService(workouts: [
            WorkoutSummary(id: "1", type: "Yoga", duration: 2700, calories: nil, distance: nil, date: today),
        ])
        let steps = MockStepsService(shouldThrow: true)

        let vm = ActivityViewModel(workoutService: workouts, stepsService: steps)
        await vm.loadActivityData()

        // Exercise should still load
        #expect(vm.todayExercise != nil)
        // Steps falls back to empty
        #expect(vm.weeklySteps.isEmpty)
        #expect(vm.todaySteps == nil)
    }

    // MARK: - Empty State

    @Test("empty state when no data")
    func emptyState() async {
        let vm = ActivityViewModel(
            workoutService: MockWorkoutService(),
            stepsService: MockStepsService()
        )
        await vm.loadActivityData()

        #expect(vm.todayExercise?.value == 0)
        #expect(vm.todaySteps?.value == 0)
        #expect(vm.recentWorkouts.isEmpty)
        #expect(vm.weeklyExerciseMinutes.count == 7) // Gap-filled with zeros
    }

    // MARK: - Multiple Workouts Same Day

    @Test("multiple workouts on same day sum correctly")
    func multipleWorkoutsSameDay() async {
        let today = calendar.startOfDay(for: Date())
        let workouts = MockWorkoutService(workouts: [
            WorkoutSummary(id: "1", type: "Running", duration: 1800, calories: nil, distance: nil, date: today),
            WorkoutSummary(id: "2", type: "Strength", duration: 2400, calories: nil, distance: nil, date: today),
            WorkoutSummary(id: "3", type: "Yoga", duration: 600, calories: nil, distance: nil, date: today),
        ])

        let vm = ActivityViewModel(workoutService: workouts, stepsService: MockStepsService())
        await vm.loadActivityData()

        #expect(vm.todayExercise!.value == 80.0) // (1800+2400+600)/60
        #expect(vm.recentWorkouts.count == 3)
    }

    // MARK: - Data Ordering

    @Test("weekly data is sorted chronologically")
    func dataSortOrder() async {
        let today = calendar.startOfDay(for: Date())
        let steps = MockStepsService(stepsCollection: [
            (date: today, sum: 5000),
            (date: calendar.date(byAdding: .day, value: -3, to: today)!, sum: 8000),
        ])

        let vm = ActivityViewModel(workoutService: MockWorkoutService(), stepsService: steps)
        await vm.loadActivityData()

        // Verify ascending date order
        for i in 1..<vm.weeklySteps.count {
            #expect(vm.weeklySteps[i].date >= vm.weeklySteps[i - 1].date)
        }
    }
}
