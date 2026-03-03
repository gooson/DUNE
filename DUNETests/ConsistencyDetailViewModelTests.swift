import Foundation
import Testing
@testable import DUNE

@Suite("ConsistencyDetailViewModel")
@MainActor
struct ConsistencyDetailViewModelTests {
    private let calendar = Calendar.current

    private func makeRecord(daysAgo: Int, durationMinutes: Double) -> ExerciseRecord {
        let base = calendar.startOfDay(for: Date())
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: base) ?? base
        return ExerciseRecord(
            date: date,
            exerciseType: "Running",
            duration: durationMinutes * 60.0
        )
    }

    @Test("Only workouts >= 20 minutes count in workoutDates")
    func minimumDurationFilter() {
        let vm = ConsistencyDetailViewModel()
        let records = [
            makeRecord(daysAgo: 0, durationMinutes: 30),
            makeRecord(daysAgo: 1, durationMinutes: 10),
            makeRecord(daysAgo: 2, durationMinutes: 45),
        ]

        vm.loadData(from: records)

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) ?? today

        #expect(vm.hasWorkout(on: today))
        #expect(vm.hasWorkout(on: twoDaysAgo))
        #expect(vm.hasWorkout(on: yesterday) == false)
    }

    @Test("Caches month calendar days and first weekday offset")
    func cachesCalendarGrid() {
        let vm = ConsistencyDetailViewModel()
        vm.loadData(from: [makeRecord(daysAgo: 0, durationMinutes: 25)])

        #expect(!vm.cachedCalendarDays.isEmpty)
        #expect(vm.cachedCalendarDays.count >= 28)
        #expect(vm.cachedCalendarDays.count <= 31)
        #expect((0...6).contains(vm.cachedFirstWeekdayOffset))
        #expect(vm.isLoading == false)
    }

    @Test("Builds streak metrics and history from valid workouts")
    func streakAndHistory() {
        let vm = ConsistencyDetailViewModel()
        let records = [
            makeRecord(daysAgo: 0, durationMinutes: 25),
            makeRecord(daysAgo: 1, durationMinutes: 35),
            makeRecord(daysAgo: 2, durationMinutes: 40),
            makeRecord(daysAgo: 5, durationMinutes: 30),
        ]

        vm.loadData(from: records)

        #expect(vm.workoutStreak != nil)
        #expect(vm.workoutStreak!.bestStreak >= 3)
        #expect(!vm.streakHistory.isEmpty)
    }
}
