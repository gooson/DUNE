import Foundation
import Testing
@testable import Dailve

@Suite("TrainingVolumeAnalysisService")
struct TrainingVolumeAnalysisServiceTests {

    // MARK: - Helpers

    private func makeWorkout(
        type: WorkoutActivityType = .running,
        duration: TimeInterval = 1800,
        calories: Double = 300,
        distance: Double? = 5000,
        daysAgo: Int = 0
    ) -> WorkoutSummary {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return WorkoutSummary(
            id: UUID().uuidString,
            type: type.rawValue,
            activityType: type,
            duration: duration,
            calories: calories,
            distance: distance,
            date: date
        )
    }

    private func makeManualRecord(
        exerciseType: String = "bench-press",
        duration: TimeInterval = 2700,
        calories: Double = 200,
        totalVolume: Double = 5000,
        daysAgo: Int = 0
    ) -> ManualExerciseSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return ManualExerciseSnapshot(
            date: date,
            exerciseType: exerciseType,
            categoryRawValue: "strength",
            duration: duration,
            calories: calories,
            totalVolume: totalVolume
        )
    }

    // MARK: - Basic Analysis

    @Test("Empty data returns zero summary")
    func emptyData() {
        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [],
            manualRecords: [],
            period: .week
        )
        #expect(result.current.totalDuration == 0)
        #expect(result.current.totalCalories == 0)
        #expect(result.current.totalSessions == 0)
        #expect(result.current.activeDays == 0)
        #expect(result.current.exerciseTypes.isEmpty)
    }

    @Test("Single HK workout aggregates correctly")
    func singleWorkout() {
        let workout = makeWorkout(duration: 1800, calories: 300, daysAgo: 1)
        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [workout],
            manualRecords: [],
            period: .week
        )
        #expect(result.current.totalDuration == 1800)
        #expect(result.current.totalCalories == 300)
        #expect(result.current.totalSessions == 1)
        #expect(result.current.activeDays == 1)
        #expect(result.current.exerciseTypes.count == 1)
        #expect(result.current.exerciseTypes.first?.typeKey == WorkoutActivityType.running.rawValue)
    }

    @Test("Manual records aggregate with manual- prefix")
    func manualRecordPrefix() {
        let record = makeManualRecord(exerciseType: "bench-press", daysAgo: 1)
        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [],
            manualRecords: [record],
            period: .week
        )
        #expect(result.current.exerciseTypes.count == 1)
        #expect(result.current.exerciseTypes.first?.typeKey == "manual-bench-press")
    }

    // MARK: - Multiple Types

    @Test("Multiple workout types sorted by duration descending")
    func multipleTypesSorted() {
        let running = makeWorkout(type: .running, duration: 3600, daysAgo: 1)
        let cycling = makeWorkout(type: .cycling, duration: 1800, daysAgo: 2)
        let yoga = makeWorkout(type: .yoga, duration: 5400, daysAgo: 3)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [running, cycling, yoga],
            manualRecords: [],
            period: .week
        )

        #expect(result.current.exerciseTypes.count == 3)
        #expect(result.current.exerciseTypes[0].typeKey == WorkoutActivityType.yoga.rawValue)
        #expect(result.current.exerciseTypes[1].typeKey == WorkoutActivityType.running.rawValue)
        #expect(result.current.exerciseTypes[2].typeKey == WorkoutActivityType.cycling.rawValue)
    }

    // MARK: - Duration Fractions

    @Test("Duration fractions sum to 1.0")
    func durationFractionsSum() {
        let running = makeWorkout(type: .running, duration: 3600, daysAgo: 1)
        let cycling = makeWorkout(type: .cycling, duration: 1800, daysAgo: 2)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [running, cycling],
            manualRecords: [],
            period: .week
        )

        let totalFraction = result.current.exerciseTypes.reduce(0.0) { $0 + $1.durationFraction }
        #expect(abs(totalFraction - 1.0) < 0.001)
    }

    // MARK: - Active Days

    @Test("Active days counts unique days")
    func activeDaysUnique() {
        // Two workouts on same day
        let w1 = makeWorkout(type: .running, duration: 1800, daysAgo: 1)
        let w2 = makeWorkout(type: .cycling, duration: 900, daysAgo: 1)
        let w3 = makeWorkout(type: .yoga, duration: 3600, daysAgo: 2)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [w1, w2, w3],
            manualRecords: [],
            period: .week
        )

        #expect(result.current.activeDays == 2)
    }

    // MARK: - Period Comparison

    @Test("Previous period populated for comparison")
    func previousPeriodExists() {
        // Workout in previous week (8 days ago)
        let oldWorkout = makeWorkout(duration: 1800, daysAgo: 8)
        let recentWorkout = makeWorkout(duration: 3600, daysAgo: 1)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [oldWorkout, recentWorkout],
            manualRecords: [],
            period: .week
        )

        #expect(result.previous != nil)
        #expect(result.previous?.totalDuration == 1800)
        #expect(result.current.totalDuration == 3600)
    }

    @Test("Duration change percentage calculated correctly")
    func durationChangePercentage() {
        let oldWorkout = makeWorkout(duration: 1000, daysAgo: 8)
        let recentWorkout = makeWorkout(duration: 2000, daysAgo: 1)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [oldWorkout, recentWorkout],
            manualRecords: [],
            period: .week
        )

        if let change = result.durationChange {
            #expect(abs(change - 100.0) < 0.1) // 100% increase
        } else {
            Issue.record("Expected duration change to be non-nil")
        }
    }

    // MARK: - Daily Breakdown

    @Test("Daily breakdown fills all days in period")
    func dailyBreakdownFillsGaps() {
        let workout = makeWorkout(daysAgo: 1)
        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [workout],
            manualRecords: [],
            period: .week
        )

        #expect(result.current.dailyBreakdown.count == 7)
    }

    @Test("Daily breakdown segments grouped by type")
    func dailyBreakdownSegments() {
        let running = makeWorkout(type: .running, duration: 1800, daysAgo: 1)
        let cycling = makeWorkout(type: .cycling, duration: 900, daysAgo: 1)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [running, cycling],
            manualRecords: [],
            period: .week
        )

        // Find the day with workouts
        let dayWithWorkouts = result.current.dailyBreakdown.first { !$0.segments.isEmpty }
        #expect(dayWithWorkouts != nil)
        #expect(dayWithWorkouts?.segments.count == 2)
    }

    // MARK: - Edge Cases

    @Test("Zero duration workouts are skipped")
    func zeroDurationSkipped() {
        let zero = makeWorkout(duration: 0, daysAgo: 1)
        let valid = makeWorkout(duration: 1800, daysAgo: 2)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [zero, valid],
            manualRecords: [],
            period: .week
        )

        #expect(result.current.totalSessions == 1)
    }

    @Test("Non-finite duration workouts are skipped")
    func nonFiniteDurationSkipped() {
        let infinite = makeWorkout(duration: .infinity, daysAgo: 1)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [infinite],
            manualRecords: [],
            period: .week
        )

        #expect(result.current.totalSessions == 0)
    }

    @Test("Distance tracked for distance-based types")
    func distanceTracked() {
        let running = makeWorkout(type: .running, duration: 1800, distance: 5000, daysAgo: 1)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [running],
            manualRecords: [],
            period: .week
        )

        #expect(result.current.exerciseTypes.first?.totalDistance == 5000)
    }

    @Test("Volume tracked for manual strength records")
    func volumeTracked() {
        let record = makeManualRecord(totalVolume: 12000, daysAgo: 1)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [],
            manualRecords: [record],
            period: .week
        )

        #expect(result.current.exerciseTypes.first?.totalVolume == 12000)
    }

    @Test("Mixed HK and manual records aggregate independently")
    func mixedSources() {
        let running = makeWorkout(type: .running, duration: 1800, calories: 300, daysAgo: 1)
        let manual = makeManualRecord(exerciseType: "squat", duration: 2700, calories: 200, daysAgo: 1)

        let result = TrainingVolumeAnalysisService.analyze(
            workouts: [running],
            manualRecords: [manual],
            period: .week
        )

        #expect(result.current.exerciseTypes.count == 2)
        #expect(result.current.totalDuration == 1800 + 2700)
        #expect(result.current.totalCalories == 300 + 200)
        #expect(result.current.totalSessions == 2)
    }
}
