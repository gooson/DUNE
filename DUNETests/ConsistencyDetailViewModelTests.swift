import Foundation
import Testing
@testable import DUNE

private enum ConsistencyDetailViewModelTestError: Error {
    case failed
}

private struct MockConsistencyWorkoutService: WorkoutQuerying {
    var workouts: [WorkoutSummary] = []
    var shouldThrow = false

    func fetchWorkouts(days: Int) async throws -> [WorkoutSummary] {
        if shouldThrow { throw ConsistencyDetailViewModelTestError.failed }
        return workouts
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        if shouldThrow { throw ConsistencyDetailViewModelTestError.failed }
        return workouts
    }
}

@Suite("ConsistencyDetailViewModel")
@MainActor
struct ConsistencyDetailViewModelTests {
    private let calendar = Calendar.current

    private func day(_ daysAgo: Int) -> Date {
        let base = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: -daysAgo, to: base) ?? base
    }

    private func makeRecord(daysAgo: Int, durationMinutes: Double) -> ExerciseRecord {
        return ExerciseRecord(
            date: day(daysAgo),
            exerciseType: "Running",
            duration: durationMinutes * 60.0
        )
    }

    private func makeWorkout(id: String, daysAgo: Int, durationMinutes: Double) -> WorkoutSummary {
        WorkoutSummary(
            id: id,
            type: WorkoutActivityType.running.typeName,
            activityType: .running,
            duration: durationMinutes * 60.0,
            calories: durationMinutes * 8,
            distance: durationMinutes * 120,
            date: day(daysAgo)
        )
    }

    @Test("Only workouts >= 20 minutes count in workoutDates")
    func minimumDurationFilter() async {
        let vm = ConsistencyDetailViewModel(workoutService: MockConsistencyWorkoutService())
        let records = [
            makeRecord(daysAgo: 0, durationMinutes: 30),
            makeRecord(daysAgo: 1, durationMinutes: 10),
            makeRecord(daysAgo: 2, durationMinutes: 45),
        ]

        await vm.loadData(from: records)

        let today = day(0)
        let yesterday = day(1)
        let twoDaysAgo = day(2)

        #expect(vm.hasWorkout(on: today))
        #expect(vm.hasWorkout(on: twoDaysAgo))
        #expect(vm.hasWorkout(on: yesterday) == false)
    }

    @Test("Caches month calendar days and first weekday offset")
    func cachesCalendarGrid() async {
        let vm = ConsistencyDetailViewModel(workoutService: MockConsistencyWorkoutService())
        await vm.loadData(from: [makeRecord(daysAgo: 0, durationMinutes: 25)])

        #expect(!vm.cachedCalendarDays.isEmpty)
        #expect(vm.cachedCalendarDays.count >= 28)
        #expect(vm.cachedCalendarDays.count <= 31)
        #expect((0...6).contains(vm.cachedFirstWeekdayOffset))
        #expect(vm.isLoading == false)
    }

    @Test("Builds streak metrics and history from valid workouts")
    func streakAndHistory() async {
        let vm = ConsistencyDetailViewModel(workoutService: MockConsistencyWorkoutService())
        let records = [
            makeRecord(daysAgo: 0, durationMinutes: 25),
            makeRecord(daysAgo: 1, durationMinutes: 35),
            makeRecord(daysAgo: 2, durationMinutes: 40),
            makeRecord(daysAgo: 5, durationMinutes: 30),
        ]

        await vm.loadData(from: records)

        #expect(vm.workoutStreak != nil)
        #expect(vm.workoutStreak!.bestStreak >= 3)
        #expect(!vm.streakHistory.isEmpty)
    }

    @Test("Merges HealthKit workouts into streak detail")
    func mergesHealthKitHistory() async {
        let vm = ConsistencyDetailViewModel(
            workoutService: MockConsistencyWorkoutService(workouts: [
                makeWorkout(id: "hk-today", daysAgo: 0, durationMinutes: 30),
                makeWorkout(id: "hk-yesterday", daysAgo: 1, durationMinutes: 25),
            ])
        )

        await vm.loadData(from: [])

        #expect(vm.workoutStreak?.currentStreak == 2)
        #expect(vm.workoutStreak?.bestStreak == 2)
        #expect(vm.workoutStreak?.monthlyCount == 2)
        #expect(vm.hasWorkout(on: day(0)))
        #expect(vm.hasWorkout(on: day(1)))
        #expect(vm.streakHistory.first?.days == 2)
    }

    @Test("Falls back to manual records when HealthKit fetch fails")
    func fallsBackToManualRecords() async {
        let vm = ConsistencyDetailViewModel(
            workoutService: MockConsistencyWorkoutService(shouldThrow: true)
        )

        await vm.loadData(from: [makeRecord(daysAgo: 0, durationMinutes: 30)])

        #expect(vm.workoutStreak?.currentStreak == 1)
        #expect(vm.workoutStreak?.bestStreak == 1)
        #expect(vm.workoutStreak?.monthlyCount == 1)
        #expect(vm.hasWorkout(on: day(0)))
    }
}

@Suite("ConsistencyWeekdayHeader")
struct ConsistencyWeekdayHeaderTests {
    @Test("Uses stable unique IDs even when labels repeat")
    func uniqueIDs() {
        let headers = ConsistencyWeekdayHeader.defaults

        #expect(headers.map(\.label) == ["S", "M", "T", "W", "T", "F", "S"])
        #expect(Set(headers.map(\.id)).count == headers.count)
    }
}
