import Testing
import Foundation
@testable import DUNE

@Suite("Yesterday Workout Summary")
@MainActor
struct YesterdayWorkoutSummaryTests {
    private let calendar = Calendar.current

    private var yesterday: Date {
        calendar.date(byAdding: .day, value: -1, to: Date())!
    }

    private func makeExerciseRecord(
        exerciseType: String = "Bench Press",
        date: Date? = nil,
        duration: TimeInterval = 1800,
        healthKitWorkoutID: String? = nil
    ) -> ExerciseRecord {
        ExerciseRecord(
            date: date ?? yesterday,
            exerciseType: exerciseType,
            duration: duration,
            healthKitWorkoutID: healthKitWorkoutID
        )
    }

    private func makeWorkoutSummary(
        id: String = UUID().uuidString,
        type: String = "Running",
        activityType: WorkoutActivityType = .running,
        date: Date? = nil,
        duration: TimeInterval = 1800,
        isFromThisApp: Bool = false
    ) -> WorkoutSummary {
        WorkoutSummary(
            id: id,
            type: type,
            activityType: activityType,
            duration: duration,
            calories: 200,
            distance: 5000,
            date: date ?? yesterday,
            isFromThisApp: isFromThisApp
        )
    }

    // MARK: - ExerciseRecord only (existing behavior)

    @Test("ExerciseRecords only — strength exercises counted")
    func exerciseRecordsOnly() {
        let vm = DashboardViewModel()
        let records = [
            makeExerciseRecord(exerciseType: "Bench Press", duration: 1800),
            makeExerciseRecord(exerciseType: "Squat", duration: 2400),
        ]
        vm.updateYesterdayWorkoutSummary(from: records)
        let summary = vm.yesterdayWorkoutSummary
        #expect(summary != nil)
        #expect(summary?.contains("2") == true, "Should show 2 exercises")
        #expect(summary?.contains("70m") == true, "Should show 70 minutes (1800+2400=4200s=70m)")
    }

    // MARK: - HealthKit WorkoutSummary only (cardio from Watch)

    @Test("HealthKit cardio workouts included via cached workouts")
    func healthKitCardioOnly() {
        let vm = DashboardViewModel()
        vm.setCachedHealthKitWorkoutsForTesting([
            makeWorkoutSummary(type: "Running", activityType: .running, duration: 1800),
        ])
        vm.updateYesterdayWorkoutSummary(from: [])
        let summary = vm.yesterdayWorkoutSummary
        #expect(summary != nil, "Cardio from HealthKit should appear in summary")
        #expect(summary?.contains("1") == true, "Should show 1 exercise")
        #expect(summary?.contains("30m") == true, "Should show 30 minutes")
    }

    // MARK: - Both sources, dedup applied

    @Test("Mixed sources with dedup — no double counting")
    func mixedSourcesDedup() {
        let hkID = "hk-workout-123"
        let vm = DashboardViewModel()
        let records = [
            makeExerciseRecord(
                exerciseType: "Running",
                duration: 1800,
                healthKitWorkoutID: hkID
            ),
        ]
        vm.setCachedHealthKitWorkoutsForTesting([
            makeWorkoutSummary(id: hkID, type: "Running", activityType: .running, duration: 1800),
        ])
        vm.updateYesterdayWorkoutSummary(from: records)
        let summary = vm.yesterdayWorkoutSummary
        #expect(summary != nil)
        #expect(summary?.contains("1") == true, "Deduped — should show 1 exercise, not 2")
    }

    @Test("Mixed sources — ExerciseRecord strength + HealthKit cardio")
    func strengthPlusCardio() {
        let vm = DashboardViewModel()
        let records = [
            makeExerciseRecord(exerciseType: "Bench Press", duration: 2400),
        ]
        vm.setCachedHealthKitWorkoutsForTesting([
            makeWorkoutSummary(type: "Running", activityType: .running, duration: 1800),
        ])
        vm.updateYesterdayWorkoutSummary(from: records)
        let summary = vm.yesterdayWorkoutSummary
        #expect(summary != nil)
        #expect(summary?.contains("2") == true, "Should show 2 exercises (1 strength + 1 cardio)")
        #expect(summary?.contains("70m") == true, "Should show 70 minutes (2400+1800=4200s=70m)")
    }

    // MARK: - No yesterday data

    @Test("No yesterday data returns nil")
    func noYesterdayData() {
        let vm = DashboardViewModel()
        vm.updateYesterdayWorkoutSummary(from: [])
        #expect(vm.yesterdayWorkoutSummary == nil)
    }

    @Test("Only today data returns nil for yesterday")
    func onlyTodayData() {
        let vm = DashboardViewModel()
        let today = Date()
        let records = [
            makeExerciseRecord(date: today, duration: 1800),
        ]
        vm.setCachedHealthKitWorkoutsForTesting([
            makeWorkoutSummary(date: today, duration: 1800),
        ])
        vm.updateYesterdayWorkoutSummary(from: records)
        #expect(vm.yesterdayWorkoutSummary == nil)
    }
}
