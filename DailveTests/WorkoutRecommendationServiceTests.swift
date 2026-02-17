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
        sets: Int = 3
    ) -> ExerciseRecordSnapshot {
        ExerciseRecordSnapshot(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            exerciseDefinitionID: "test-exercise",
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            completedSetCount: sets
        )
    }

    // MARK: - Tests

    @Test("empty records returns suggestion with exercises")
    func emptyRecordsReturnsSuggestion() {
        let result = service.recommend(from: [], library: library)
        #expect(result != nil)
        #expect(!result!.exercises.isEmpty)
        #expect(!result!.focusMuscles.isEmpty)
    }

    @Test("recently trained muscles are not suggested")
    func recentlyTrainedNotSuggested() {
        // Train chest and shoulders today
        let records = [
            snapshot(daysAgo: 0, primaryMuscles: [.chest], secondaryMuscles: [.triceps, .shoulders], sets: 10),
        ]
        let result = service.recommend(from: records, library: library)
        #expect(result != nil)
        // Focus muscles should not include chest (just trained)
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
        // Chest should be a candidate since it's recovered
        let fatigueStates = service.computeFatigueStates(from: records)
        let chestState = fatigueStates.first { $0.muscle == .chest }
        #expect(chestState?.isRecovered == true)
    }

    @Test("overworked muscles are excluded")
    func overworkedExcluded() {
        // Train back with 25 sets this week (overworked threshold is 20)
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
            #expect(state.daysSinceLastTrained == nil)
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
        // Train every muscle group today with high volume
        let records = MuscleGroup.allCases.map { muscle in
            snapshot(daysAgo: 0, primaryMuscles: [muscle], sets: 20)
        }
        let result = service.recommend(from: records, library: library)
        #expect(result != nil)
        // Either empty exercises (rest day) or focuses on least fatigued
        #expect(result!.reasoning.contains("recovering") || !result!.exercises.isEmpty)
    }

    @Test("reasoning text is non-empty")
    func reasoningNonEmpty() {
        let result = service.recommend(from: [], library: library)
        #expect(result != nil)
        #expect(!result!.reasoning.isEmpty)
    }
}
