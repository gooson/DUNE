import Foundation
import Observation

/// Orchestrates a multi-exercise compound workout (superset or circuit)
@Observable
@MainActor
final class CompoundWorkoutViewModel {
    let config: CompoundWorkoutConfig

    /// One WorkoutSessionViewModel per exercise
    private(set) var exerciseViewModels: [WorkoutSessionViewModel]

    /// Current exercise index within a round
    private(set) var currentExerciseIndex: Int = 0

    /// Current round (1-based)
    private(set) var currentRound: Int = 1

    /// Whether the inter-exercise rest timer should be shown
    private(set) var isTransitioning: Bool = false

    /// Session start time
    let sessionStartTime: Date = Date()

    var isSaving: Bool = false
    var validationError: String?

    var currentExercise: ExerciseDefinition {
        config.exercises[currentExerciseIndex]
    }

    var currentViewModel: WorkoutSessionViewModel {
        exerciseViewModels[currentExerciseIndex]
    }

    var isLastExerciseInRound: Bool {
        currentExerciseIndex == config.exercises.count - 1
    }

    var isLastRound: Bool {
        currentRound >= config.totalRounds
    }

    var isComplete: Bool {
        isLastExerciseInRound && isLastRound
    }

    /// Total completed sets across all exercises
    var totalCompletedSets: Int {
        exerciseViewModels.reduce(0) { $0 + $1.completedSetCount }
    }

    /// Progress through rounds (0.0 - 1.0)
    var roundProgress: Double {
        guard config.totalRounds > 0 else { return 0 }
        let exercisesPerRound = config.exercises.count
        let totalSteps = config.totalRounds * exercisesPerRound
        guard totalSteps > 0 else { return 0 }
        let completedSteps = (currentRound - 1) * exercisesPerRound + currentExerciseIndex
        return Double(completedSteps) / Double(totalSteps)
    }

    init(config: CompoundWorkoutConfig) {
        self.config = config
        self.exerciseViewModels = config.exercises.map { exercise in
            WorkoutSessionViewModel(exercise: exercise)
        }
    }

    // MARK: - Navigation

    /// Advance to the next exercise in the circuit/superset
    func advanceToNextExercise() {
        if currentExerciseIndex < config.exercises.count - 1 {
            // Move to next exercise in this round
            currentExerciseIndex += 1
            isTransitioning = true
        } else if currentRound < config.totalRounds {
            // Start next round
            currentRound += 1
            currentExerciseIndex = 0
            isTransitioning = true
            // Add a new set for each exercise for the new round
            for vm in exerciseViewModels {
                vm.addSet()
            }
        }
        // If we're at the last exercise of the last round, do nothing (user should save)
    }

    /// Called when the transition rest timer completes
    func finishTransition() {
        isTransitioning = false
    }

    /// Go to a specific exercise by index
    func goToExercise(at index: Int) {
        guard config.exercises.indices.contains(index) else { return }
        currentExerciseIndex = index
        isTransitioning = false
    }

    // MARK: - Record Creation

    /// Creates all ExerciseRecords for the completed workout.
    /// Returns records only for exercises that have completed sets.
    func createAllRecords(weightUnit: WeightUnit = .kg) -> [ExerciseRecord] {
        guard !isSaving else { return [] }
        isSaving = true

        var records: [ExerciseRecord] = []
        for vm in exerciseViewModels {
            if let record = vm.createValidatedRecord(weightUnit: weightUnit) {
                records.append(record)
            }
        }

        if records.isEmpty {
            validationError = "Complete at least one set in any exercise"
            isSaving = false
        }
        // When records exist, caller (View) must reset isSaving after insert
        return records
    }

    /// Call from View after successfully inserting records into ModelContext
    func didFinishSaving() {
        isSaving = false
    }

    // MARK: - Load Previous Data

    func loadPreviousSets(from records: [ExerciseRecord]) {
        for vm in exerciseViewModels {
            vm.loadPreviousSets(from: records)
        }
    }
}
