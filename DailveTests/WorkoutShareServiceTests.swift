import Foundation
import Testing
@testable import Dailve

@Suite("WorkoutShareService")
@MainActor
struct WorkoutShareServiceTests {

    // MARK: - buildShareData

    @Test("buildShareData creates correct exercise name")
    func buildShareDataExerciseName() {
        let input = makeInput(exerciseType: "Bench Press")
        let data = WorkoutShareService.buildShareData(from: input)
        #expect(data.exerciseName == "Bench Press")
    }

    @Test("buildShareData maps completed sets correctly")
    func buildShareDataSets() {
        let sets = [
            ExerciseRecordShareInput.SetInput(
                setNumber: 1, weight: 60, reps: 10,
                duration: nil, distance: nil, setType: .working
            ),
            ExerciseRecordShareInput.SetInput(
                setNumber: 2, weight: 70, reps: 8,
                duration: nil, distance: nil, setType: .working
            )
        ]
        let input = makeInput(completedSets: sets)
        let data = WorkoutShareService.buildShareData(from: input)

        #expect(data.sets.count == 2)
        #expect(data.sets[0].weight == 60)
        #expect(data.sets[0].reps == 10)
        #expect(data.sets[1].weight == 70)
        #expect(data.sets[1].reps == 8)
    }

    @Test("buildShareData includes personal best when provided")
    func buildShareDataPersonalBest() {
        let input = makeInput()
        let data = WorkoutShareService.buildShareData(from: input, personalBest: "100 kg")
        #expect(data.personalBest == "100 kg")
    }

    @Test("buildShareData personal best is nil by default")
    func buildShareDataNoPB() {
        let input = makeInput()
        let data = WorkoutShareService.buildShareData(from: input)
        #expect(data.personalBest == nil)
    }

    @Test("buildShareData maps exercise icon correctly")
    func buildShareDataIcon() {
        let input = makeInput(exerciseType: "Running")
        let data = WorkoutShareService.buildShareData(from: input)
        #expect(data.exerciseIcon == "figure.run")
    }

    @Test("buildShareData includes calories")
    func buildShareDataCalories() {
        let input = makeInput(bestCalories: 250.0)
        let data = WorkoutShareService.buildShareData(from: input)
        #expect(data.estimatedCalories == 250.0)
    }

    @Test("buildShareData includes duration")
    func buildShareDataDuration() {
        let input = makeInput(duration: 1800)
        let data = WorkoutShareService.buildShareData(from: input)
        #expect(data.duration == 1800)
    }

    @Test("buildShareData maps set types correctly")
    func buildShareDataSetTypes() {
        let sets = [
            ExerciseRecordShareInput.SetInput(
                setNumber: 1, weight: 40, reps: 15,
                duration: nil, distance: nil, setType: .warmup
            ),
            ExerciseRecordShareInput.SetInput(
                setNumber: 2, weight: 80, reps: 5,
                duration: nil, distance: nil, setType: .failure
            )
        ]
        let input = makeInput(completedSets: sets)
        let data = WorkoutShareService.buildShareData(from: input)

        #expect(data.sets[0].setType == .warmup)
        #expect(data.sets[1].setType == .failure)
    }

    @Test("buildShareData handles empty sets")
    func buildShareDataEmptySets() {
        let input = makeInput(completedSets: [])
        let data = WorkoutShareService.buildShareData(from: input)
        #expect(data.sets.isEmpty)
    }

    // MARK: - renderShareImage

    @Test("renderShareImage produces non-nil image")
    func renderShareImageProducesImage() {
        let input = makeInput(completedSets: [
            ExerciseRecordShareInput.SetInput(
                setNumber: 1, weight: 60, reps: 10,
                duration: nil, distance: nil, setType: .working
            )
        ])
        let data = WorkoutShareService.buildShareData(from: input)
        let image = WorkoutShareService.renderShareImage(data: data, weightUnit: .kg)
        #expect(image != nil)
    }

    @Test("renderShareImage respects weight unit (lb)")
    func renderShareImageWeightUnit() {
        let input = makeInput(completedSets: [
            ExerciseRecordShareInput.SetInput(
                setNumber: 1, weight: 100, reps: 5,
                duration: nil, distance: nil, setType: .working
            )
        ])
        let data = WorkoutShareService.buildShareData(from: input)
        let image = WorkoutShareService.renderShareImage(data: data, weightUnit: .lb)
        // Just verify it produces an image — content validation would require pixel inspection
        #expect(image != nil)
    }

    // MARK: - Helpers

    private func makeInput(
        exerciseType: String = "Bench Press",
        duration: TimeInterval = 600,
        bestCalories: Double? = nil,
        completedSets: [ExerciseRecordShareInput.SetInput] = [
            ExerciseRecordShareInput.SetInput(
                setNumber: 1, weight: 60, reps: 10,
                duration: nil, distance: nil, setType: .working
            )
        ]
    ) -> ExerciseRecordShareInput {
        ExerciseRecordShareInput(
            exerciseType: exerciseType,
            date: Date(),
            duration: duration,
            bestCalories: bestCalories,
            completedSets: completedSets
        )
    }
}
