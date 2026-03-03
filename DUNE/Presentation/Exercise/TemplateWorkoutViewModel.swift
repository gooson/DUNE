import Foundation
import Observation

/// Orchestrates a sequential template workout where each exercise
/// is recorded individually and saved immediately upon completion.
@Observable
@MainActor
final class TemplateWorkoutViewModel {
    let config: TemplateWorkoutConfig

    /// One WorkoutSessionViewModel per exercise
    private(set) var exerciseViewModels: [WorkoutSessionViewModel]

    /// Current exercise index
    private(set) var currentExerciseIndex: Int = 0

    /// Status of each exercise
    private(set) var exerciseStatuses: [TemplateExerciseStatus]

    /// Session start time
    let sessionStartTime: Date = Date()

    var isSaving = false
    var validationError: String?

    // MARK: - Computed Properties

    var currentExercise: ExerciseDefinition {
        config.exercises[currentExerciseIndex]
    }

    var currentViewModel: WorkoutSessionViewModel {
        exerciseViewModels[currentExerciseIndex]
    }

    var currentStatus: TemplateExerciseStatus {
        exerciseStatuses[currentExerciseIndex]
    }

    var completedCount: Int {
        exerciseStatuses.filter { $0 == .completed }.count
    }

    var totalExercises: Int {
        config.exercises.count
    }

    var isAllDone: Bool {
        exerciseStatuses.allSatisfy { $0 == .completed || $0 == .skipped }
    }

    var hasAnyCompleted: Bool {
        exerciseStatuses.contains(.completed)
    }

    /// Total completed sets across all exercises
    var totalCompletedSets: Int {
        exerciseViewModels.reduce(0) { $0 + $1.completedSetCount }
    }

    // MARK: - Init

    init(config: TemplateWorkoutConfig) {
        self.config = config
        self.exerciseViewModels = config.exercises.map { exercise in
            WorkoutSessionViewModel(exercise: exercise)
        }
        self.exerciseStatuses = Array(repeating: .pending, count: config.exercises.count)

        // Mark first exercise as in-progress
        if !config.exercises.isEmpty {
            exerciseStatuses[0] = .inProgress
        }

        // Pre-fill sets from template defaults
        prefillFromTemplateDefaults()
    }

    // MARK: - Template Default Prefill

    private func prefillFromTemplateDefaults() {
        for (index, entry) in config.templateEntries.enumerated() {
            guard index < exerciseViewModels.count else { break }
            let vm = exerciseViewModels[index]

            // Adjust set count to match template default
            let targetSets = entry.defaultSets
            while vm.sets.count < targetSets {
                vm.addSet()
            }
            // Remove excess sets (default init creates WorkoutDefaults.setCount)
            while vm.sets.count > targetSets {
                vm.removeSet(at: vm.sets.count - 1)
            }

            // Pre-fill weight/reps from template defaults
            if let defaultWeight = entry.defaultWeightKg {
                let weightStr = defaultWeight.formatted(.number.precision(.fractionLength(0...1)))
                for i in vm.sets.indices {
                    if vm.sets[i].weight.isEmpty {
                        vm.sets[i].weight = weightStr
                    }
                }
            }
            let defaultReps = entry.defaultReps
            for i in vm.sets.indices {
                if vm.sets[i].reps.isEmpty {
                    vm.sets[i].reps = "\(defaultReps)"
                }
            }
        }
    }

    // MARK: - Navigation

    /// Advance to the next pending/in-progress exercise
    func advanceToNext() {
        // Find next non-completed, non-skipped exercise
        if let nextIndex = findNextPendingIndex(after: currentExerciseIndex) {
            currentExerciseIndex = nextIndex
            exerciseStatuses[nextIndex] = .inProgress
        }
    }

    /// Skip the current exercise
    func skipCurrent() {
        exerciseStatuses[currentExerciseIndex] = .skipped
        if let nextIndex = findNextPendingIndex(after: currentExerciseIndex) {
            currentExerciseIndex = nextIndex
            exerciseStatuses[nextIndex] = .inProgress
        }
    }

    /// Jump to a specific exercise
    func goToExercise(at index: Int) {
        guard config.exercises.indices.contains(index) else { return }
        let status = exerciseStatuses[index]
        // Allow jumping to pending or skipped exercises (re-do)
        if status == .pending || status == .skipped {
            currentExerciseIndex = index
            exerciseStatuses[index] = .inProgress
        }
    }

    // MARK: - Record Creation

    /// Create a validated record for the current exercise and mark it as completed.
    /// Returns nil if validation fails.
    func createRecordForCurrent(weightUnit: WeightUnit = .kg) -> ExerciseRecord? {
        guard !isSaving else { return nil }
        isSaving = true
        validationError = nil

        let vm = currentViewModel
        guard let record = vm.createValidatedRecord(weightUnit: weightUnit) else {
            validationError = vm.validationError
            isSaving = false
            return nil
        }

        exerciseStatuses[currentExerciseIndex] = .completed
        return record
    }

    /// Call from View after successfully inserting record into ModelContext
    func didFinishSaving() {
        isSaving = false
        currentViewModel.didFinishSaving()
    }

    // MARK: - Load Previous Data

    func loadPreviousSets(from records: [ExerciseRecord], weightUnit: WeightUnit = .kg) {
        for vm in exerciseViewModels {
            vm.loadPreviousSets(from: records, weightUnit: weightUnit)
        }
    }

    // MARK: - Private Helpers

    private func findNextPendingIndex(after index: Int) -> Int? {
        // Search forward from current index
        for i in (index + 1)..<config.exercises.count {
            if exerciseStatuses[i] == .pending || exerciseStatuses[i] == .skipped {
                return i
            }
        }
        // Wrap around and search from beginning
        for i in 0..<index {
            if exerciseStatuses[i] == .pending || exerciseStatuses[i] == .skipped {
                return i
            }
        }
        return nil
    }
}
