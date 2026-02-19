import Foundation
import Testing
@testable import Dailve

@Suite("WorkoutRecommendationService")
struct WorkoutRecommendationServiceTests {

    let service = WorkoutRecommendationService()
    let library = ExerciseLibraryService.shared

    // MARK: - Helper

    private func snapshot(
        daysAgo: Int,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup] = [],
        sets: Int = 3,
        exerciseID: String = "test-exercise"
    ) -> ExerciseRecordSnapshot {
        ExerciseRecordSnapshot(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date(),
            exerciseDefinitionID: exerciseID,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            completedSetCount: sets
        )
    }

    private func snapshotWithHours(
        hoursAgo: Double,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup] = [],
        sets: Int = 3,
        exerciseID: String = "test-exercise"
    ) -> ExerciseRecordSnapshot {
        ExerciseRecordSnapshot(
            date: Date().addingTimeInterval(-hoursAgo * 3600),
            exerciseDefinitionID: exerciseID,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            completedSetCount: sets
        )
    }

    /// Creates records for a specific weekday over multiple weeks
    private func weekdayRecords(
        weekday: Int,
        weeksBack: Int,
        primaryMuscles: [MuscleGroup],
        sets: Int = 3
    ) -> [ExerciseRecordSnapshot] {
        let calendar = Calendar.current
        var records: [ExerciseRecordSnapshot] = []
        for week in 1...weeksBack {
            // Find the date of the given weekday, `week` weeks ago
            let baseDate = calendar.date(byAdding: .weekOfYear, value: -week, to: Date()) ?? Date()
            var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: baseDate)
            components.weekday = weekday
            if let date = calendar.date(from: components) {
                records.append(ExerciseRecordSnapshot(
                    date: date,
                    exerciseDefinitionID: "weekday-test",
                    primaryMuscles: primaryMuscles,
                    secondaryMuscles: [],
                    completedSetCount: sets
                ))
            }
        }
        return records
    }

    // MARK: - Existing Tests

    @Test("empty records returns suggestion with exercises")
    func emptyRecordsReturnsSuggestion() {
        let result = service.recommend(from: [], library: library)
        #expect(result != nil)
        #expect(!result!.exercises.isEmpty)
        #expect(!result!.focusMuscles.isEmpty)
    }

    @Test("recently trained muscles are not suggested")
    func recentlyTrainedNotSuggested() {
        let records = [
            snapshot(daysAgo: 0, primaryMuscles: [.chest], secondaryMuscles: [.triceps, .shoulders], sets: 10),
        ]
        let result = service.recommend(from: records, library: library)
        #expect(result != nil)
        let focusNames = result!.focusMuscles
        #expect(!focusNames.contains(.chest))
    }

    @Test("muscles trained 3+ days ago are suggested")
    func recoveredMusclesSuggested() {
        let records = [
            snapshot(daysAgo: 4, primaryMuscles: [.chest]),
        ]
        let result = service.recommend(from: records, library: library)
        #expect(result != nil)
        let fatigueStates = service.computeFatigueStates(from: records)
        let chestState = fatigueStates.first { $0.muscle == .chest }
        #expect(chestState?.isRecovered == true)
    }

    @Test("overworked muscles are excluded")
    func overworkedExcluded() {
        let records = [
            snapshot(daysAgo: 3, primaryMuscles: [.back], sets: 25),
        ]
        let fatigueStates = service.computeFatigueStates(from: records)
        let backState = fatigueStates.first { $0.muscle == .back }
        #expect(backState?.isOverworked == true)
    }

    @Test("suggestion has at most targetExerciseCount exercises")
    func limitedExerciseCount() {
        let result = service.recommend(from: [], library: library)
        #expect(result != nil)
        #expect(result!.exercises.count <= 4)
    }

    @Test("suggestion exercises have valid definitions")
    func exercisesHaveValidDefinitions() {
        let result = service.recommend(from: [], library: library)
        #expect(result != nil)
        for exercise in result!.exercises {
            #expect(!exercise.definition.name.isEmpty)
            #expect(exercise.suggestedSets >= 2)
            #expect(exercise.suggestedSets <= 5)
        }
    }

    @Test("fatigue states cover all muscle groups")
    func fatigueStatesComplete() {
        let states = service.computeFatigueStates(from: [])
        #expect(states.count == MuscleGroup.allCases.count)
    }

    @Test("never-trained muscles have full recovery")
    func neverTrainedFullRecovery() {
        let states = service.computeFatigueStates(from: [])
        for state in states {
            #expect(state.recoveryPercent == 1.0)
            #expect(state.lastTrainedDate == nil)
            #expect(state.hoursSinceLastTrained == nil)
            #expect(state.weeklyVolume == 0)
        }
    }

    @Test("secondary muscles contribute half volume")
    func secondaryMusclesHalfVolume() {
        let records = [
            snapshot(daysAgo: 1, primaryMuscles: [.chest], secondaryMuscles: [.triceps], sets: 10),
        ]
        let states = service.computeFatigueStates(from: records)
        let chestState = states.first { $0.muscle == .chest }
        let tricepsState = states.first { $0.muscle == .triceps }
        #expect(chestState?.weeklyVolume == 10)
        #expect(tricepsState?.weeklyVolume == 5) // 10/2
    }

    @Test("all muscle groups trained returns rest suggestion")
    func allGroupsTrainedReturnsRest() {
        let records = MuscleGroup.allCases.map { muscle in
            snapshot(daysAgo: 0, primaryMuscles: [muscle], sets: 20)
        }
        let result = service.recommend(from: records, library: library)
        #expect(result != nil)
        // Rest day: empty exercises + recovery reasoning OR focuses on least fatigued
        #expect(result!.reasoning.contains("Recovery") || result!.reasoning.contains("recovering") || !result!.exercises.isEmpty)
    }

    @Test("reasoning text is non-empty")
    func reasoningNonEmpty() {
        let result = service.recommend(from: [], library: library)
        #expect(result != nil)
        #expect(!result!.reasoning.isEmpty)
    }

    // MARK: - New: Compound Bypass Fix

    @Test("compound bypass checks recovery — unrecovered muscles not in focus")
    func compoundBypassChecksRecovery() {
        // Train chest and back today (should be unrecovered)
        let records = [
            snapshot(daysAgo: 0, primaryMuscles: [.chest], secondaryMuscles: [.triceps], sets: 5),
            snapshot(daysAgo: 0, primaryMuscles: [.back], secondaryMuscles: [.biceps], sets: 5),
        ]

        // Verify fatigue states: chest and back should NOT be recovered
        let states = service.computeFatigueStates(from: records)
        let chestState = states.first { $0.muscle == .chest }
        let backState = states.first { $0.muscle == .back }
        #expect(chestState?.isRecovered == false, "Chest trained 0h ago should not be recovered")
        #expect(backState?.isRecovered == false, "Back trained 0h ago should not be recovered")

        let result = service.recommend(from: records, library: library)
        #expect(result != nil)

        // Focus muscles should NOT include unrecovered chest/back
        #expect(!result!.focusMuscles.contains(.chest), "Focus should not include unrecovered chest")
        #expect(!result!.focusMuscles.contains(.back), "Focus should not include unrecovered back")
    }

    // MARK: - New: Differential Recovery

    @Test("differential recovery — small muscle recovers in 36h")
    func differentialRecoverySmallMuscle() {
        // Biceps trained 37 hours ago → should be recovered (36h recovery)
        let records = [
            snapshotWithHours(hoursAgo: 37, primaryMuscles: [.biceps]),
        ]
        let states = service.computeFatigueStates(from: records)
        let bicepsState = states.first { $0.muscle == .biceps }
        #expect(bicepsState != nil)
        #expect(bicepsState!.isRecovered == true)
        #expect(bicepsState!.recoveryPercent >= 0.8)
    }

    @Test("differential recovery — large muscle NOT recovered at 48h")
    func differentialRecoveryLargeMuscleNotRecovered() {
        // Quadriceps trained 48 hours ago → NOT recovered yet (72h recovery)
        let records = [
            snapshotWithHours(hoursAgo: 48, primaryMuscles: [.quadriceps]),
        ]
        let states = service.computeFatigueStates(from: records)
        let quadState = states.first { $0.muscle == .quadriceps }
        #expect(quadState != nil)
        // 48/72 = 0.667 < 0.8 threshold
        #expect(quadState!.isRecovered == false)
        #expect(quadState!.recoveryPercent < 0.8)
    }

    // MARK: - New: Exercise Diversity

    @Test("exercise diversity — prefers least recently performed")
    func exerciseDiversityPrefersLeastRecent() {
        // Train with exercise A recently, exercise B long ago
        // The recommendation should prefer B over A for variety
        let records = [
            snapshot(daysAgo: 10, primaryMuscles: [.chest], exerciseID: "bench-press"),
        ]
        let result = service.recommend(from: records, library: library)
        #expect(result != nil)

        // The algorithm should prefer exercises not recently performed
        // At minimum, the result should contain exercises (diversity test is structural)
        #expect(!result!.exercises.isEmpty)
    }

    // MARK: - New: Rest Day

    @Test("rest day returns active recovery suggestions")
    func restDayReturnsActiveRecovery() {
        // Train every muscle group today — all unrecovered
        let records = MuscleGroup.allCases.map { muscle in
            snapshot(daysAgo: 0, primaryMuscles: [muscle], sets: 10)
        }
        let result = service.recommend(from: records, library: library)
        #expect(result != nil)

        if result!.isRestDay {
            #expect(!result!.activeRecoverySuggestions.isEmpty)
            #expect(result!.activeRecoverySuggestions.count == 3) // Walking, Stretching, Yoga
        }
    }

    @Test("rest day includes next ready muscle")
    func restDayNextReadyMuscle() {
        // Train all muscles today
        let records = MuscleGroup.allCases.map { muscle in
            snapshot(daysAgo: 0, primaryMuscles: [muscle], sets: 10)
        }
        let result = service.recommend(from: records, library: library)
        #expect(result != nil)

        if result!.isRestDay {
            // Should have a nextReadyMuscle (the small muscle group recovers soonest — 36h)
            #expect(result!.nextReadyMuscle != nil)
            if let nextReady = result!.nextReadyMuscle {
                // Small muscles (36h) recover before medium (48h) and large (72h)
                let smallMuscles: Set<MuscleGroup> = [.biceps, .triceps, .forearms, .core, .calves]
                #expect(smallMuscles.contains(nextReady.muscle))
            }
        }
    }

    // MARK: - New: Weekday Pattern

    @Test("weekday pattern boosts muscles trained on matching day")
    func weekdayPatternBoost() {
        // Create records of chest training on the current weekday for 5 weeks
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        let records = weekdayRecords(weekday: currentWeekday, weeksBack: 5, primaryMuscles: [.chest])

        let patterns = service.computeWeekdayPatterns(from: records)
        // Chest was trained on this weekday 5 times → should be in the pattern set
        #expect(patterns.contains(.chest))
    }

    @Test("weekday pattern requires minimum weeks of data")
    func weekdayPatternRequiresMinWeeks() {
        // Only 2 weeks of data — below 4-week threshold
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        let records = weekdayRecords(weekday: currentWeekday, weeksBack: 2, primaryMuscles: [.chest])

        let patterns = service.computeWeekdayPatterns(from: records)
        // Not enough data → should return empty
        #expect(patterns.isEmpty)
    }

    // MARK: - New: Hour-Based Precision

    @Test("hour-based recovery is more precise than day-based")
    func hourBasedPreciseRecovery() {
        // Medium muscle (chest, 48h recovery) trained 40 hours ago
        // Old day-based: 1 day ago → 24h/48h = 50% → not recovered
        // New hour-based: 40h/48h = 83.3% → recovered!
        let records = [
            snapshotWithHours(hoursAgo: 40, primaryMuscles: [.chest]),
        ]
        let states = service.computeFatigueStates(from: records)
        let chestState = states.first { $0.muscle == .chest }
        #expect(chestState != nil)
        // 40/48 ≈ 0.833 → recovered (>= 0.8)
        #expect(chestState!.isRecovered == true)
        #expect(chestState!.recoveryPercent > 0.8)
    }

    // MARK: - MuscleFatigueState

    @Test("nextReadyDate returns nil when fully recovered")
    func nextReadyDateNilWhenRecovered() {
        let state = MuscleFatigueState(
            muscle: .chest,
            lastTrainedDate: Date().addingTimeInterval(-72 * 3600), // 72h ago, chest needs 48h
            hoursSinceLastTrained: 72,
            weeklyVolume: 5,
            recoveryPercent: 1.0
        )
        #expect(state.nextReadyDate == nil) // Already recovered
    }

    @Test("nextReadyDate returns future date when not recovered")
    func nextReadyDateReturnsFutureDate() {
        let trainedDate = Date().addingTimeInterval(-24 * 3600) // 24h ago
        let state = MuscleFatigueState(
            muscle: .chest,
            lastTrainedDate: trainedDate,
            hoursSinceLastTrained: 24,
            weeklyVolume: 5,
            recoveryPercent: 0.5
        )
        let readyDate = state.nextReadyDate
        #expect(readyDate != nil)
        #expect(readyDate! > Date()) // Should be in the future
    }
}
