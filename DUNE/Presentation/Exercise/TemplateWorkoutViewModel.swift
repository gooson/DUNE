import Foundation
import Observation

// MARK: - Draft Persistence

/// Codable snapshot of a template workout session for background/crash recovery
struct TemplateWorkoutDraft: Codable {
    let exerciseIDs: [String]
    let exerciseSets: [[DraftSet]]
    let exerciseStatusRaws: [String]
    let currentExerciseIndex: Int
    let sessionStartTime: Date
    let savedAt: Date

    struct DraftSet: Codable {
        let setNumber: Int
        let weight: String
        let reps: String
        let duration: String
        let distance: String
        let level: String?
        let isCompleted: Bool
        let setTypeRaw: String
        let restDuration: TimeInterval?
    }

    private static let userDefaultsKey = "com.raftel.dailve.template_workout_draft"

    /// Encode failure preserves previous draft (if any) to avoid data loss.
    static func save(_ draft: TemplateWorkoutDraft) {
        guard let data = try? JSONEncoder().encode(draft) else {
            AppLogger.exercise.error("Failed to encode template workout draft")
            return
        }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    static func load() -> TemplateWorkoutDraft? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        guard let draft = try? JSONDecoder().decode(TemplateWorkoutDraft.self, from: data) else {
            AppLogger.exercise.error("Failed to decode template workout draft")
            return nil
        }
        return draft
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

/// Orchestrates a sequential template workout where each exercise
/// is recorded individually and saved immediately upon completion.
@Observable
@MainActor
final class TemplateWorkoutViewModel {
    let config: TemplateWorkoutConfig

    /// Mutable exercise arrays — copied from config at init, reorderable during session.
    var exercises: [ExerciseDefinition]
    var templateEntries: [TemplateEntry]

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
    private var didPrefillTemplateDefaults = false

    // MARK: - Computed Properties

    var currentExercise: ExerciseDefinition {
        exercises[currentExerciseIndex]
    }

    var currentViewModel: WorkoutSessionViewModel {
        exerciseViewModels[currentExerciseIndex]
    }

    var completedCount: Int {
        exerciseStatuses.filter { $0 == .completed }.count
    }

    var totalExercises: Int {
        exercises.count
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
        self.exercises = config.exercises
        self.templateEntries = config.templateEntries
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
        for (index, entry) in templateEntries.enumerated() {
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
        guard !didPrefillTemplateDefaults else { return }
        didPrefillTemplateDefaults = true

        for (index, entry) in templateEntries.enumerated() {
            guard index < exerciseViewModels.count else { break }
            let vm = exerciseViewModels[index]
            let profile = TemplateExerciseProfile(exercise: exercises[index])

            guard profile.showsStrengthDefaultsEditor else {
                continue
            }

            // Pre-fill weight (convert from stored kg to display unit)
            if let defaultWeightKg = entry.defaultWeightKg {
                let displayWeight = weightUnit.fromKg(defaultWeightKg)
                let weightStr = displayWeight.formatted(.number.precision(.fractionLength(0...1)))
                for i in vm.sets.indices {
                    vm.sets[i].weight = weightStr
                }
            }

            // Template defaults should replace the generic starter reps created by WorkoutSessionViewModel.
            let defaultReps = entry.defaultReps
            for i in vm.sets.indices {
                vm.sets[i].reps = "\(defaultReps)"
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

    /// Skip the current exercise and advance to the next pending.
    /// Returns `true` if there is a next pending exercise, `false` if all are done.
    @discardableResult
    func skipAndAdvance() -> Bool {
        exerciseStatuses[currentExerciseIndex] = .skipped
        if let nextIndex = findNextPendingIndex(after: currentExerciseIndex) {
            currentExerciseIndex = nextIndex
            exerciseStatuses[nextIndex] = .inProgress
            return true
        }
        return false
    }

    /// Skip the current exercise (used by tab-bar skip, where return value is not needed).
    func skipCurrent() {
        skipAndAdvance()
    }

    /// Jump to a specific exercise
    func goToExercise(at index: Int) {
        guard exercises.indices.contains(index) else { return }
        let status = exerciseStatuses[index]
        // Allow jumping to pending or skipped exercises (re-do)
        if status == .pending || status == .skipped {
            currentExerciseIndex = index
            exerciseStatuses[index] = .inProgress
        }
    }

    // MARK: - Reorder

    /// Whether reordering is available (need at least 2 non-completed exercises)
    var canReorderExercises: Bool {
        var nonCompleted = 0
        for status in exerciseStatuses {
            if status != .completed {
                nonCompleted += 1
                if nonCompleted >= 2 { return true }
            }
        }
        return false
    }

    /// Reorder exercises by moving from source offsets to destination.
    /// All parallel arrays are moved in sync. currentExerciseIndex is tracked.
    func moveExercise(from source: IndexSet, to destination: Int) {
        // Refuse to move completed exercises
        guard source.allSatisfy({ exerciseStatuses[$0] != .completed }) else { return }

        // Track current exercise identity before move
        let currentExerciseID = exercises[currentExerciseIndex].id

        exercises.move(fromOffsets: source, toOffset: destination)
        templateEntries.move(fromOffsets: source, toOffset: destination)
        exerciseViewModels.move(fromOffsets: source, toOffset: destination)
        exerciseStatuses.move(fromOffsets: source, toOffset: destination)

        // Restore currentExerciseIndex to follow the same exercise
        if let newIndex = exercises.firstIndex(where: { $0.id == currentExerciseID }) {
            currentExerciseIndex = newIndex
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
        for i in (index + 1)..<exercises.count {
            if exerciseStatuses[i] == .pending {
                return i
            }
        }
        // Wrap around and search from beginning
        for i in 0..<index {
            if exerciseStatuses[i] == .pending {
                return i
            }
        }
        return nil
    }

    // MARK: - Draft Persistence

    func saveDraft() {
        let exerciseSets = exerciseViewModels.map { vm in
            vm.sets.map { set in
                TemplateWorkoutDraft.DraftSet(
                    setNumber: set.setNumber,
                    weight: set.weight,
                    reps: set.reps,
                    duration: set.duration,
                    distance: set.distance,
                    level: set.level,
                    isCompleted: set.isCompleted,
                    setTypeRaw: set.setType.rawValue,
                    restDuration: set.restDuration
                )
            }
        }
        let statusRaws = exerciseStatuses.map { status -> String in
            switch status {
            case .pending: "pending"
            case .inProgress: "inProgress"
            case .completed: "completed"
            case .skipped: "skipped"
            }
        }
        let draft = TemplateWorkoutDraft(
            exerciseIDs: exercises.map(\.id),
            exerciseSets: exerciseSets,
            exerciseStatusRaws: statusRaws,
            currentExerciseIndex: currentExerciseIndex,
            sessionStartTime: sessionStartTime,
            savedAt: Date()
        )
        TemplateWorkoutDraft.save(draft)
    }

    @discardableResult
    func restoreFromDraft(_ draft: TemplateWorkoutDraft) -> Bool {
        // Verify same exercise set (order may differ after reorder)
        let currentIDs = Set(exercises.map(\.id))
        let draftIDs = Set(draft.exerciseIDs)
        guard currentIDs == draftIDs else { return false }
        guard draft.exerciseSets.count == exerciseViewModels.count else { return false }
        guard draft.exerciseStatusRaws.count == exerciseStatuses.count else { return false }

        // Reorder arrays to match draft's saved order (preserves reorder state)
        if exercises.map(\.id) != draft.exerciseIDs {
            let idOrder = draft.exerciseIDs
            let sortOrder = { (a: ExerciseDefinition, b: ExerciseDefinition) -> Bool in
                let ai = idOrder.firstIndex(of: a.id) ?? 0
                let bi = idOrder.firstIndex(of: b.id) ?? 0
                return ai < bi
            }
            let indices = exercises.indices.sorted { sortOrder(exercises[$0], exercises[$1]) }
            exercises = indices.map { exercises[$0] }
            templateEntries = indices.map { templateEntries[$0] }
            exerciseViewModels = indices.map { exerciseViewModels[$0] }
            exerciseStatuses = indices.map { exerciseStatuses[$0] }
        }

        currentExerciseIndex = max(0, min(draft.currentExerciseIndex, exercises.count - 1))

        // Restore statuses
        for (i, raw) in draft.exerciseStatusRaws.enumerated() {
            switch raw {
            case "pending": exerciseStatuses[i] = .pending
            case "inProgress": exerciseStatuses[i] = .inProgress
            case "completed": exerciseStatuses[i] = .completed
            case "skipped": exerciseStatuses[i] = .skipped
            default: break
            }
        }

        // Restore sets
        for (vmIndex, draftSets) in draft.exerciseSets.enumerated() {
            let vm = exerciseViewModels[vmIndex]
            vm.sets = draftSets.map { draftSet in
                var editable = EditableSet(setNumber: draftSet.setNumber)
                editable.weight = draftSet.weight
                editable.reps = draftSet.reps
                editable.duration = draftSet.duration
                editable.distance = draftSet.distance
                editable.level = draftSet.level ?? ""
                editable.isCompleted = draftSet.isCompleted
                editable.setType = SetType(rawValue: draftSet.setTypeRaw) ?? .working
                editable.restDuration = draftSet.restDuration
                return editable
            }
        }
        return true
    }

    static func clearDraft() {
        TemplateWorkoutDraft.clear()
    }
}
