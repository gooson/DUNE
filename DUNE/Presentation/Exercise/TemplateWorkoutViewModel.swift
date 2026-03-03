import Foundation
import Observation

/// Orchestrates a sequential template workout where each exercise
/// is recorded individually and saved immediately upon completion.
@Observable
@MainActor
final class TemplateWorkoutViewModel {
    let config: TemplateWorkoutConfig

    /// One WorkoutSessionViewModel per exercise
    var exerciseViewModels: [WorkoutSessionViewModel]

    /// Current exercise index
    var currentExerciseIndex: Int = 0

    /// Status of each exercise
    var exerciseStatuses: [TemplateExerciseStatus]

    /// Session start time
    let sessionStartTime: Date = Date()

    var isSaving = false
    var validationError: String?

    /// Tracks which exercise index is being saved (for deferred .completed)
    private var savingExerciseIndex: Int?

    // MARK: - Computed Properties

    var currentExercise: ExerciseDefinition {
        config.exercises[currentExerciseIndex]
    }

    var currentViewModel: WorkoutSessionViewModel {
        exerciseViewModels[currentExerciseIndex]
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

        // Adjust set counts from template defaults (doesn't need weight unit)
        adjustSetCounts()
    }

    // MARK: - Template Default Prefill

    /// Adjusts set counts per exercise to match template defaults.
    /// Called during init (no weight unit needed).
    private func adjustSetCounts() {
        for (index, entry) in config.templateEntries.enumerated() {
            guard index < exerciseViewModels.count else { break }
            let vm = exerciseViewModels[index]

            let targetSets = Swift.max(1, entry.defaultSets)
            while vm.sets.count < targetSets {
                vm.addSet()
            }
            while vm.sets.count > targetSets {
                vm.removeSet(at: vm.sets.count - 1)
            }
        }
    }

    /// Pre-fills weight and reps from template defaults, converting weight to display unit.
    /// Called from View's `.onAppear` with the user's preferred weight unit.
    func prefillFromTemplateDefaults(weightUnit: WeightUnit) {
        for (index, entry) in config.templateEntries.enumerated() {
            guard index < exerciseViewModels.count else { break }
            let vm = exerciseViewModels[index]

            // Pre-fill weight (convert from stored kg to display unit)
            if let defaultWeightKg = entry.defaultWeightKg {
                let displayWeight = weightUnit.fromKg(defaultWeightKg)
                let weightStr = displayWeight.formatted(.number.precision(.fractionLength(0...1)))
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

    /// Create a validated record for the current exercise.
    /// Returns nil if validation fails. Does NOT mark as completed —
    /// call `didFinishSaving()` after confirmed persistence.
    func createRecordForCurrent(weightUnit: WeightUnit = .kg) -> ExerciseRecord? {
        guard !isSaving else { return nil }
        isSaving = true
        validationError = nil
        savingExerciseIndex = currentExerciseIndex

        let vm = currentViewModel
        guard let record = vm.createValidatedRecord(weightUnit: weightUnit) else {
            validationError = vm.validationError
            isSaving = false
            savingExerciseIndex = nil
            return nil
        }

        return record
    }

    /// Call from View after successfully inserting record into ModelContext.
    /// Marks the exercise as completed and resets saving state.
    func didFinishSaving() {
        if let index = savingExerciseIndex {
            exerciseStatuses[index] = .completed
            exerciseViewModels[index].didFinishSaving()
        }
        isSaving = false
        savingExerciseIndex = nil
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
