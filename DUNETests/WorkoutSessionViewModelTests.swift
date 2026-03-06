import Foundation
import Testing
@testable import DUNE

@Suite("WorkoutSessionViewModel")
@MainActor
struct WorkoutSessionViewModelTests {
    // Helper to create a test exercise definition
    private func makeExercise(
        inputType: ExerciseInputType = .setsRepsWeight,
        metValue: Double = 6.0,
        cardioSecondaryUnit: CardioSecondaryUnit? = nil
    ) -> ExerciseDefinition {
        ExerciseDefinition(
            id: "test-bench-press",
            name: "Bench Press",
            localizedName: "벤치프레스",
            category: .strength,
            inputType: inputType,
            primaryMuscles: [.chest],
            secondaryMuscles: [.triceps, .shoulders],
            equipment: .barbell,
            metValue: metValue,
            cardioSecondaryUnit: cardioSecondaryUnit
        )
    }

    @Test("Initial state has default number of empty sets")
    func initialState() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)

        #expect(vm.sets.count == WorkoutDefaults.setCount)
        #expect(vm.sets[0].setNumber == 1)
        #expect(vm.sets[0].weight.isEmpty)
        #expect(vm.sets[0].reps == "\(WorkoutDefaults.defaultReps)")
        #expect(vm.sets.last?.setNumber == WorkoutDefaults.setCount)
    }

    @Test("Initial state keeps reps empty for non-reps inputs")
    func initialStateForDurationInput() {
        let exercise = makeExercise(inputType: .durationDistance)
        let vm = WorkoutSessionViewModel(exercise: exercise)

        #expect(vm.sets.count == WorkoutDefaults.setCount)
        #expect(vm.sets[0].reps.isEmpty)
    }

    @Test("addSet increments set number")
    func addSet() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        let initialCount = vm.sets.count

        vm.addSet()
        #expect(vm.sets.count == initialCount + 1)
        #expect(vm.sets.last?.setNumber == initialCount + 1)
    }

    @Test("removeSet at valid index")
    func removeSet() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        let initialCount = vm.sets.count

        vm.removeSet(at: 1)
        #expect(vm.sets.count == initialCount - 1)
        // Set numbers should be renumbered
        for (i, set) in vm.sets.enumerated() {
            #expect(set.setNumber == i + 1)
        }
    }

    @Test("removeSet ignores invalid index")
    func removeSetInvalidIndex() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        let initialCount = vm.sets.count

        vm.removeSet(at: 100)
        #expect(vm.sets.count == initialCount)
    }

    @Test("toggleSetCompletion changes isCompleted")
    func toggleCompletion() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)

        #expect(!vm.sets[0].isCompleted)
        let first = vm.toggleSetCompletion(at: 0)
        #expect(first == true)
        #expect(vm.sets[0].isCompleted)
        let second = vm.toggleSetCompletion(at: 0)
        #expect(second == false)
        #expect(!vm.sets[0].isCompleted)
    }

    @Test("fillSetFromPrevious copies weight and reps")
    func fillFromPreviousCopiesCoreValues() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.previousSets = [
            PreviousSetInfo(
                weight: 60,
                reps: 10,
                duration: nil,
                distance: nil,
                restDuration: nil
            )
        ]

        vm.fillSetFromPrevious(at: 0)
        #expect(vm.sets[0].weight == "60")
        #expect(vm.sets[0].reps == "10")
    }

    @Test("fillSetFromPrevious copies duration and distance")
    func fillFromPreviousCopiesDurationDistance() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.previousSets = [
            PreviousSetInfo(
                weight: nil,
                reps: nil,
                duration: 1800,
                distance: 5.5,
                restDuration: nil
            )
        ]

        vm.fillSetFromPrevious(at: 0)
        #expect(vm.sets[0].duration == "30")
        #expect(vm.sets[0].distance == "5.5")
    }

    @Test("createValidatedRecord returns nil with no completed sets")
    func noCompletedSets() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        // Not completed

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord succeeds with valid completed set")
    func validRecord() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.exerciseType == "Bench Press")
        #expect(record?.exerciseDefinitionID == "test-bench-press")
        #expect(record?.completedSets.count == 1)
    }

    @Test("createValidatedRecord rejects reps > 1000")
    func repsOverLimit() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].reps = "1500"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord rejects weight > 500")
    func weightOverLimit() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "600"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("isSaving prevents duplicate record creation")
    func isSavingGuard() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true
        vm.isSaving = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
    }

    @Test("Calorie estimation uses injected service")
    func calorieEstimation() {
        struct MockCalorieService: CalorieEstimating {
            func estimate(metValue: Double, bodyWeightKg: Double, durationSeconds: TimeInterval, restSeconds: TimeInterval) -> Double? {
                return 250.0
            }
        }

        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise, calorieService: MockCalorieService())
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.estimatedCalories == 250.0)
    }

    @Test("Stair level adjusts MET and persists as set intensity")
    func stairLevelAdjustsMETAndPersistsIntensity() {
        struct CapturingCalorieService: CalorieEstimating {
            let onEstimate: @Sendable (Double) -> Void

            func estimate(metValue: Double, bodyWeightKg: Double, durationSeconds: TimeInterval, restSeconds: TimeInterval) -> Double? {
                onEstimate(metValue)
                return 111
            }
        }

        var capturedMET: Double = 0
        let exercise = ExerciseDefinition(
            id: "stair-climber",
            name: "Stair Climber",
            localizedName: "천국의 계단",
            category: .cardio,
            inputType: .durationDistance,
            primaryMuscles: [.quadriceps],
            secondaryMuscles: [.glutes],
            equipment: .machine,
            metValue: 9.0,
            cardioSecondaryUnit: .floors
        )

        let vm = WorkoutSessionViewModel(
            exercise: exercise,
            calorieService: CapturingCalorieService { met in
                capturedMET = met
            }
        )

        vm.sets[0].duration = "20"
        vm.sets[0].reps = "60"
        vm.sets[0].level = "8"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.completedSets.first?.intensity == 8)
        #expect(abs(capturedMET - 14.4) < 0.0001)
    }

    @Test("Exercise input type is passed through")
    func inputType() {
        let exercise = makeExercise(inputType: .setsReps)
        let vm = WorkoutSessionViewModel(exercise: exercise)

        #expect(vm.exercise.inputType == .setsReps)
    }

    @Test("Memo is included in record")
    func memoIncluded() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true
        vm.memo = "Good session"

        let record = vm.createValidatedRecord()
        #expect(record?.memo == "Good session")
    }

    @Test("createValidatedRecord rejects duration > 500 for durationDistance")
    func durationOverLimit() {
        let exercise = makeExercise(inputType: .durationDistance)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "600"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord rejects distance > 500 for durationDistance")
    func distanceOverLimit() {
        let exercise = makeExercise(inputType: .durationDistance)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].distance = "600"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord succeeds with valid durationDistance set")
    func validDurationDistance() {
        let exercise = makeExercise(inputType: .durationDistance)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].distance = "5.0"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        // Duration stored in seconds: 30 min * 60 = 1800
        let setDuration = record?.completedSets.first?.duration
        #expect(setDuration == 1800.0)
    }

    @Test("createValidatedRecord validates duration for durationIntensity")
    func durationIntensityValidation() {
        let exercise = makeExercise(inputType: .durationIntensity)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "0"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("createValidatedRecord stores roundsBased without per-set intensity")
    func roundsBasedSetStoresNoIntensity() {
        let exercise = makeExercise(inputType: .roundsBased)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].reps = "8"
        vm.sets[0].duration = "45"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.completedSets.first?.intensity == nil)
    }

    @Test("createValidatedRecord validates roundsBased input")
    func roundsBasedValidation() {
        let exercise = makeExercise(inputType: .roundsBased)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].reps = "0"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("validateSetForCompletion rejects zero reps for reps-based input")
    func validateSetForCompletionRejectsZeroReps() {
        let exercise = makeExercise(inputType: .setsRepsWeight)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].reps = "0"

        let valid = vm.validateSetForCompletion(at: 0)
        #expect(!valid)
        #expect(vm.validationError != nil)
    }

    @Test("validateSetForCompletion accepts valid reps for reps-based input")
    func validateSetForCompletionAcceptsPositiveReps() {
        let exercise = makeExercise(inputType: .setsRepsWeight)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].reps = "10"

        let valid = vm.validateSetForCompletion(at: 0)
        #expect(valid)
        #expect(vm.validationError == nil)
    }

    // MARK: - Cardio Secondary Unit Tests

    @Test("durationDistance with meters unit converts to km in WorkoutSet")
    func metersConvertedToKm() {
        let exercise = makeExercise(inputType: .durationDistance, cardioSecondaryUnit: .meters)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].distance = "1500"  // 1500 meters
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        let setDistance = record?.completedSets.first?.distance
        #expect(setDistance == 1.5)  // 1500m = 1.5km
    }

    @Test("durationDistance with km unit stores distance as-is")
    func kmStoredDirectly() {
        let exercise = makeExercise(inputType: .durationDistance, cardioSecondaryUnit: .km)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].distance = "5.0"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.completedSets.first?.distance == 5.0)
    }

    @Test("durationDistance with floors unit stores in reps field")
    func floorsStoredInReps() {
        let exercise = makeExercise(inputType: .durationDistance, cardioSecondaryUnit: .floors)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "20"
        vm.sets[0].reps = "50"  // 50 floors
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.completedSets.first?.reps == 50)
        #expect(record?.completedSets.first?.distance == nil)
    }

    @Test("durationDistance with count unit stores in reps field")
    func countStoredInReps() {
        let exercise = makeExercise(inputType: .durationDistance, cardioSecondaryUnit: .count)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "10"
        vm.sets[0].reps = "500"  // 500 jumps
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.completedSets.first?.reps == 500)
        #expect(record?.completedSets.first?.distance == nil)
    }

    @Test("durationDistance with timeOnly unit stores only duration")
    func timeOnlyUnitDurationOnly() {
        let exercise = makeExercise(inputType: .durationDistance, cardioSecondaryUnit: .timeOnly)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "45"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.completedSets.first?.duration == 2700.0)  // 45 * 60
        #expect(record?.completedSets.first?.distance == nil)
        #expect(record?.completedSets.first?.reps == nil)
    }

    @Test("durationDistance with meters rejects values over 50000")
    func metersOverLimit() {
        let exercise = makeExercise(inputType: .durationDistance, cardioSecondaryUnit: .meters)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].distance = "60000"  // Over 50000m limit
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("durationDistance with floors rejects values over 500")
    func floorsOverLimit() {
        let exercise = makeExercise(inputType: .durationDistance, cardioSecondaryUnit: .floors)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].reps = "600"  // Over 500 floors limit
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record == nil)
        #expect(vm.validationError != nil)
    }

    @Test("durationDistance nil cardioSecondaryUnit defaults to km behavior")
    func nilUnitDefaultsToKm() {
        let exercise = makeExercise(inputType: .durationDistance, cardioSecondaryUnit: nil)
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].duration = "30"
        vm.sets[0].distance = "5.0"
        vm.sets[0].isCompleted = true

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.completedSets.first?.distance == 5.0)
    }

    // MARK: - Rest Duration Prefill Tests

    @Test("resolveRestDuration returns previous session rest when available")
    func resolveRestFromPreviousSession() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.previousSets = [
            PreviousSetInfo(weight: 60, reps: 10, duration: nil, distance: nil, restDuration: 90)
        ]

        let resolved = vm.resolveRestDuration(forSetAt: 0)
        #expect(resolved == 90)
    }

    @Test("resolveRestDuration falls back to template when no previous rest")
    func resolveRestFromTemplate() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.templateRestDuration = 120
        vm.previousSets = [
            PreviousSetInfo(weight: 60, reps: 10, duration: nil, distance: nil, restDuration: nil)
        ]

        let resolved = vm.resolveRestDuration(forSetAt: 0)
        #expect(resolved == 120)
    }

    @Test("resolveRestDuration falls back to global default when no previous or template")
    func resolveRestFromGlobalDefault() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.previousSets = [
            PreviousSetInfo(weight: 60, reps: 10, duration: nil, distance: nil, restDuration: nil)
        ]

        let resolved = vm.resolveRestDuration(forSetAt: 0)
        #expect(resolved == WorkoutDefaults.restSeconds)
    }

    @Test("resolveRestDuration previous rest takes priority over template")
    func resolveRestPreviousOverTemplate() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.templateRestDuration = 120
        vm.previousSets = [
            PreviousSetInfo(weight: 60, reps: 10, duration: nil, distance: nil, restDuration: 45)
        ]

        let resolved = vm.resolveRestDuration(forSetAt: 0)
        #expect(resolved == 45)
    }

    @Test("createValidatedRecord stores restDuration from editable set")
    func restDurationStoredInRecord() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true
        vm.sets[0].restDuration = 90

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.completedSets.first?.restDuration == 90)
    }

    @Test("createValidatedRecord preserves nil restDuration")
    func nilRestDurationPreserved() {
        let exercise = makeExercise()
        let vm = WorkoutSessionViewModel(exercise: exercise)
        vm.sets[0].weight = "60"
        vm.sets[0].reps = "10"
        vm.sets[0].isCompleted = true
        // restDuration not set (nil)

        let record = vm.createValidatedRecord()
        #expect(record != nil)
        #expect(record?.completedSets.first?.restDuration == nil)
    }
}
