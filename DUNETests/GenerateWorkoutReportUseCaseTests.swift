import Foundation
import Testing
@testable import DUNE

@Suite("GenerateWorkoutReportUseCase")
struct GenerateWorkoutReportUseCaseTests {

    // MARK: - Mock Formatter

    struct MockFormatter: WorkoutReportFormatting {
        func format(report: WorkoutReport) async -> String {
            "Mock summary: \(report.stats.totalSessions) sessions"
        }
    }

    let sut = GenerateWorkoutReportUseCase(formatter: MockFormatter())
    let calendar = Calendar.current

    // MARK: - Helpers

    private func makeRecord(
        daysAgo: Int = 0,
        exerciseName: String = "Bench Press",
        primaryMuscles: [MuscleGroup] = [.chest],
        secondaryMuscles: [MuscleGroup] = [.triceps],
        sets: Int = 4,
        totalWeight: Double? = 320,
        totalReps: Int? = 40,
        durationMinutes: Double? = 45
    ) -> ExerciseRecordSnapshot {
        ExerciseRecordSnapshot(
            date: calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
            exerciseDefinitionID: UUID().uuidString,
            exerciseName: exerciseName,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            completedSetCount: sets,
            totalWeight: totalWeight,
            totalReps: totalReps,
            durationMinutes: durationMinutes
        )
    }

    private func makeDefaultInput(
        records: [ExerciseRecordSnapshot]? = nil,
        previousPeriodVolume: Double? = nil,
        workoutStreak: Int = 0,
        newPersonalRecords: Int = 0,
        newExerciseNames: [String] = []
    ) -> GenerateWorkoutReportUseCase.Input {
        let start = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return .init(
            records: records ?? [
                makeRecord(daysAgo: 1),
                makeRecord(daysAgo: 3, exerciseName: "Squat", primaryMuscles: [.quadriceps], secondaryMuscles: [.hamstrings]),
                makeRecord(daysAgo: 5, exerciseName: "Deadlift", primaryMuscles: [.back], secondaryMuscles: [.hamstrings]),
            ],
            period: .weekly,
            startDate: start,
            endDate: Date(),
            previousPeriodVolume: previousPeriodVolume,
            workoutStreak: workoutStreak,
            newPersonalRecords: newPersonalRecords,
            newExerciseNames: newExerciseNames
        )
    }

    // MARK: - Basic Stats

    @Test("Computes total sessions correctly")
    func totalSessions() async {
        let result = await sut.execute(input: makeDefaultInput())
        #expect(result.stats.totalSessions == 3)
    }

    @Test("Computes total volume from weights")
    func totalVolume() async {
        let result = await sut.execute(input: makeDefaultInput())
        #expect(result.stats.totalVolume == 960) // 320 * 3
    }

    @Test("Computes active days")
    func activeDays() async {
        let result = await sut.execute(input: makeDefaultInput())
        #expect(result.stats.activeDays == 3)
    }

    @Test("Computes total duration")
    func totalDuration() async {
        let result = await sut.execute(input: makeDefaultInput())
        #expect(result.stats.totalDuration == 135) // 45 * 3
    }

    // MARK: - Empty Data

    @Test("Empty records produce zero stats")
    func emptyRecords() async {
        let result = await sut.execute(input: makeDefaultInput(records: []))
        #expect(result.stats.totalSessions == 0)
        #expect(result.stats.totalVolume == 0)
        #expect(result.stats.activeDays == 0)
        #expect(result.muscleBreakdown.isEmpty)
    }

    // MARK: - Muscle Breakdown

    @Test("Muscle breakdown includes primary muscles")
    func muscleBreakdownPrimary() async {
        let result = await sut.execute(input: makeDefaultInput())
        let muscles = Set(result.muscleBreakdown.map(\.muscleGroup))
        #expect(muscles.contains(.chest))
        #expect(muscles.contains(.quadriceps))
        #expect(muscles.contains(.back))
    }

    @Test("Secondary muscles get 50% volume")
    func muscleBreakdownSecondary() async {
        let records = [makeRecord(primaryMuscles: [.chest], secondaryMuscles: [.triceps], totalWeight: 200)]
        let result = await sut.execute(input: makeDefaultInput(records: records))
        let chestStat = result.muscleBreakdown.first { $0.muscleGroup == .chest }
        let tricepsStat = result.muscleBreakdown.first { $0.muscleGroup == .triceps }
        #expect(chestStat?.volume == 200)
        #expect(tricepsStat?.volume == 100) // 50% of primary
    }

    // MARK: - Volume Change

    @Test("Volume change calculated vs previous period")
    func volumeChange() async {
        let records = [makeRecord(totalWeight: 500)]
        let result = await sut.execute(input: makeDefaultInput(
            records: records,
            previousPeriodVolume: 400
        ))
        // (500 - 400) / 400 = 0.25
        #expect(result.stats.volumeChangePercent != nil)
        #expect(abs((result.stats.volumeChangePercent ?? 0) - 0.25) < 0.01)
    }

    @Test("No previous volume → nil change")
    func volumeChangeNil() async {
        let result = await sut.execute(input: makeDefaultInput(previousPeriodVolume: nil))
        #expect(result.stats.volumeChangePercent == nil)
    }

    // MARK: - Highlights

    @Test("Personal records generate highlight")
    func personalRecordHighlight() async {
        let result = await sut.execute(input: makeDefaultInput(newPersonalRecords: 2))
        #expect(result.highlights.contains { $0.type == .personalRecord })
    }

    @Test("Streak >= 3 generates highlight")
    func streakHighlight() async {
        let result = await sut.execute(input: makeDefaultInput(workoutStreak: 5))
        #expect(result.highlights.contains { $0.type == .streak })
    }

    @Test("No streak < 3 → no streak highlight")
    func noStreakHighlight() async {
        let result = await sut.execute(input: makeDefaultInput(workoutStreak: 2))
        #expect(!result.highlights.contains { $0.type == .streak })
    }

    @Test("New exercises generate highlight")
    func newExerciseHighlight() async {
        let result = await sut.execute(input: makeDefaultInput(newExerciseNames: ["Overhead Press"]))
        #expect(result.highlights.contains { $0.type == .newExercise })
    }

    @Test("Volume increase > 10% generates highlight")
    func volumeIncreaseHighlight() async {
        let records = [makeRecord(totalWeight: 600)]
        let result = await sut.execute(input: makeDefaultInput(
            records: records,
            previousPeriodVolume: 400
        ))
        #expect(result.highlights.contains { $0.type == .volumeIncrease })
    }

    // MARK: - Formatted Summary

    @Test("Formatted summary is populated by formatter")
    func formattedSummary() async {
        let result = await sut.execute(input: makeDefaultInput())
        #expect(result.formattedSummary != nil)
        #expect(result.formattedSummary?.contains("Mock summary") == true)
    }

    // MARK: - Period

    @Test("Weekly period set correctly")
    func weeklyPeriod() async {
        let result = await sut.execute(input: makeDefaultInput())
        #expect(result.period == .weekly)
    }
}
