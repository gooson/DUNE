import Foundation
import Observation

/// Editable set data for the workout session UI (not persisted until save)
struct EditableSet: Identifiable {
    let id = UUID()
    var setNumber: Int
    var weight: String = ""
    var reps: String = ""
    var duration: String = ""
    var distance: String = ""
    var intensity: String = ""
    var isCompleted: Bool = false
    var setType: SetType = .working
}

/// Previous session data for inline display
struct PreviousSetInfo: Sendable {
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let distance: Double?
}

// MARK: - Draft Persistence

/// Codable snapshot of a workout session for background/crash recovery
struct WorkoutSessionDraft: Codable {
    let exerciseDefinition: ExerciseDefinition
    let sets: [DraftSet]
    let sessionStartTime: Date
    let memo: String
    let savedAt: Date

    struct DraftSet: Codable {
        let setNumber: Int
        let weight: String
        let reps: String
        let duration: String
        let distance: String
        let intensity: String
        let isCompleted: Bool
        let setTypeRaw: String
    }

    private static let userDefaultsKey = "com.raftel.dailve.workoutDraft"

    static func save(_ draft: WorkoutSessionDraft) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    static func load() -> WorkoutSessionDraft? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(WorkoutSessionDraft.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}

@Observable
@MainActor
final class WorkoutSessionViewModel {
    let exercise: ExerciseDefinition

    var sets: [EditableSet] = []
    var previousSets: [PreviousSetInfo] = []
    var sessionStartTime: Date = Date()
    var memo: String = ""

    var isSaving = false
    var validationError: String?

    private let calorieService: CalorieEstimating
    private let maxWeightKg = 500.0
    private let maxReps = 1000
    private let maxDurationMinutes = 500
    private let maxDistanceKm = 500.0
    private let maxIntensity = 10
    private let maxMemoLength = 500
    private let defaultRestSeconds: TimeInterval = 90

    /// Body weight for calorie estimation (fetched externally, defaults to 70kg)
    var bodyWeightKg: Double = 70.0

    init(
        exercise: ExerciseDefinition,
        calorieService: CalorieEstimating = CalorieEstimationService()
    ) {
        self.exercise = exercise
        self.calorieService = calorieService
        addSet()
    }

    // MARK: - Set Management

    func addSet(weightUnit: WeightUnit = .kg) {
        let newSetNumber = sets.count + 1
        var newSet = EditableSet(setNumber: newSetNumber)

        // Auto-fill from previous session if available
        let previousIndex = newSetNumber - 1
        if previousIndex < previousSets.count {
            let prev = previousSets[previousIndex]
            if let weight = prev.weight {
                let displayWeight = weightUnit.fromKg(weight)
                newSet.weight = displayWeight.formatted(.number.precision(.fractionLength(0...1)))
            }
            if let reps = prev.reps {
                newSet.reps = "\(reps)"
            }
            if let duration = prev.duration {
                newSet.duration = "\(Int(duration / 60))"
            }
            if let distance = prev.distance {
                newSet.distance = distance.formatted(.number.precision(.fractionLength(0...2)))
            }
        }
        // If no previous data, auto-fill from last current set
        else if let lastSet = sets.last {
            newSet.weight = lastSet.weight
            newSet.reps = lastSet.reps
            newSet.duration = lastSet.duration
            newSet.distance = lastSet.distance
        }

        sets.append(newSet)
    }

    /// Creates a new set pre-filled with the last completed set's values.
    func repeatLastCompletedSet() {
        guard let lastCompleted = sets.last(where: \.isCompleted) else { return }
        let newSetNumber = sets.count + 1
        var newSet = EditableSet(setNumber: newSetNumber)
        newSet.weight = lastCompleted.weight
        newSet.reps = lastCompleted.reps
        newSet.duration = lastCompleted.duration
        newSet.distance = lastCompleted.distance
        newSet.intensity = lastCompleted.intensity
        sets.append(newSet)
    }

    var hasCompletedSet: Bool {
        sets.contains(where: \.isCompleted)
    }

    func removeSet(at index: Int) {
        guard sets.indices.contains(index) else { return }
        sets.remove(at: index)
        // Renumber remaining sets
        for i in sets.indices {
            sets[i].setNumber = i + 1
        }
    }

    func toggleSetCompletion(at index: Int) -> Bool {
        guard sets.indices.contains(index) else { return false }
        sets[index].isCompleted.toggle()
        return sets[index].isCompleted
    }

    // MARK: - Previous Session

    func loadPreviousSets(from records: [ExerciseRecord]) {
        // Find the most recent record for this exercise
        let matching = records
            .filter { $0.exerciseDefinitionID == exercise.id }
            .sorted { $0.date > $1.date }

        guard let lastSession = matching.first else {
            previousSets = []
            return
        }

        previousSets = lastSession.completedSets.map { set in
            PreviousSetInfo(
                weight: set.weight,
                reps: set.reps,
                duration: set.duration,
                distance: set.distance
            )
        }
    }

    func previousSetInfo(for setNumber: Int) -> PreviousSetInfo? {
        let index = setNumber - 1
        guard index >= 0, index < previousSets.count else { return nil }
        return previousSets[index]
    }

    func fillSetFromPrevious(at index: Int, weightUnit: WeightUnit = .kg) {
        guard sets.indices.contains(index) else { return }
        guard let prev = previousSetInfo(for: sets[index].setNumber) else { return }
        if let weight = prev.weight {
            let displayWeight = weightUnit.fromKg(weight)
            sets[index].weight = displayWeight.formatted(.number.precision(.fractionLength(0...1)))
        }
        if let reps = prev.reps {
            sets[index].reps = "\(reps)"
        }
        if let duration = prev.duration {
            sets[index].duration = "\(Int(duration / 60))"
        }
        if let distance = prev.distance {
            sets[index].distance = distance.formatted(.number.precision(.fractionLength(0...2)))
        }
    }

    // MARK: - Calorie Estimation

    var estimatedCalories: Double? {
        let totalDuration = sessionDurationSeconds
        let totalRest = totalRestSeconds
        return calorieService.estimate(
            metValue: exercise.metValue,
            bodyWeightKg: bodyWeightKg,
            durationSeconds: totalDuration,
            restSeconds: totalRest
        )
    }

    private var sessionDurationSeconds: TimeInterval {
        Date().timeIntervalSince(sessionStartTime)
    }

    private var totalRestSeconds: TimeInterval {
        let restSets = max(completedSetCount - 1, 0)
        return Double(restSets) * defaultRestSeconds
    }

    // MARK: - Summary (cached to avoid redundant filter calls)

    private var _cachedCompletedSets: [EditableSet]?
    private var _cachedSetsSnapshot: [EditableSet]?

    private var cachedCompletedSets: [EditableSet] {
        if _cachedSetsSnapshot?.count == sets.count,
           _cachedSetsSnapshot?.elementsEqual(sets, by: { $0.id == $1.id && $0.isCompleted == $1.isCompleted }) == true,
           let cached = _cachedCompletedSets {
            return cached
        }
        let completed = sets.filter(\.isCompleted)
        _cachedCompletedSets = completed
        _cachedSetsSnapshot = sets
        return completed
    }

    var completedSetCount: Int {
        cachedCompletedSets.count
    }

    var weightRange: String? {
        let weights = cachedCompletedSets.compactMap { Double($0.weight) }.filter { $0 > 0 }
        guard !weights.isEmpty else { return nil }
        let minW = weights.min() ?? 0
        let maxW = weights.max() ?? 0
        if minW == maxW {
            return minW.formatted(.number.precision(.fractionLength(0...1))) + "kg"
        }
        return "\(minW.formatted(.number.precision(.fractionLength(0...1))))-\(maxW.formatted(.number.precision(.fractionLength(0...1))))kg"
    }

    var totalReps: Int {
        cachedCompletedSets.compactMap { Int($0.reps) }.reduce(0, +)
    }

    // MARK: - Draft Persistence

    func saveDraft() {
        let draftSets = sets.map { set in
            WorkoutSessionDraft.DraftSet(
                setNumber: set.setNumber,
                weight: set.weight,
                reps: set.reps,
                duration: set.duration,
                distance: set.distance,
                intensity: set.intensity,
                isCompleted: set.isCompleted,
                setTypeRaw: set.setType.rawValue
            )
        }
        let draft = WorkoutSessionDraft(
            exerciseDefinition: exercise,
            sets: draftSets,
            sessionStartTime: sessionStartTime,
            memo: memo,
            savedAt: Date()
        )
        WorkoutSessionDraft.save(draft)
    }

    func restoreFromDraft(_ draft: WorkoutSessionDraft) {
        sessionStartTime = draft.sessionStartTime
        memo = draft.memo
        sets = draft.sets.map { draftSet in
            var editable = EditableSet(setNumber: draftSet.setNumber)
            editable.weight = draftSet.weight
            editable.reps = draftSet.reps
            editable.duration = draftSet.duration
            editable.distance = draftSet.distance
            editable.intensity = draftSet.intensity
            editable.isCompleted = draftSet.isCompleted
            editable.setType = SetType(rawValue: draftSet.setTypeRaw) ?? .working
            return editable
        }
    }

    static func clearDraft() {
        WorkoutSessionDraft.clear()
    }

    // MARK: - Validation & Record Creation

    func createValidatedRecord(weightUnit: WeightUnit = .kg) -> ExerciseRecord? {
        guard !isSaving else { return nil }
        validationError = nil

        let completedSets = cachedCompletedSets
        guard !completedSets.isEmpty else {
            validationError = "Complete at least one set"
            return nil
        }

        // Validate each completed set
        for set in completedSets {
            if exercise.inputType == .setsRepsWeight || exercise.inputType == .setsReps {
                let trimmed = set.reps.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, let reps = Int(trimmed), reps > 0, reps <= maxReps else {
                    validationError = "Reps must be between 1 and \(maxReps)"
                    return nil
                }
            }
            if exercise.inputType == .setsRepsWeight {
                let trimmed = set.weight.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let maxDisplay = weightUnit.fromKg(maxWeightKg)
                    guard let weight = Double(trimmed), weight >= 0, weight <= maxDisplay else {
                        validationError = "Weight must be between 0 and \(Int(maxDisplay))\(weightUnit.displayName)"
                        return nil
                    }
                }
            }
            if exercise.inputType == .durationDistance || exercise.inputType == .durationIntensity {
                let trimmed = set.duration.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    guard let mins = Int(trimmed), mins > 0, mins <= maxDurationMinutes else {
                        validationError = "Duration must be between 1 and \(maxDurationMinutes) minutes"
                        return nil
                    }
                }
            }
            if exercise.inputType == .durationDistance {
                let trimmed = set.distance.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    guard let dist = Double(trimmed), dist > 0, dist <= maxDistanceKm else {
                        validationError = "Distance must be between 0.1 and \(Int(maxDistanceKm))km"
                        return nil
                    }
                }
            }
            if exercise.inputType == .durationIntensity {
                let trimmed = set.intensity.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    guard let val = Int(trimmed), val >= 1, val <= maxIntensity else {
                        validationError = "Intensity must be between 1 and \(maxIntensity)"
                        return nil
                    }
                }
            }
            if exercise.inputType == .roundsBased {
                let trimmedReps = set.reps.trimmingCharacters(in: .whitespaces)
                guard !trimmedReps.isEmpty, let reps = Int(trimmedReps), reps > 0, reps <= maxReps else {
                    validationError = "Rounds must be between 1 and \(maxReps)"
                    return nil
                }
                let trimmedDur = set.duration.trimmingCharacters(in: .whitespaces)
                if !trimmedDur.isEmpty {
                    guard let secs = Int(trimmedDur), secs > 0, secs <= maxDurationMinutes * 60 else {
                        validationError = "Duration must be between 1 and \(maxDurationMinutes * 60) seconds"
                        return nil
                    }
                }
            }
        }

        isSaving = true

        let duration = Date().timeIntervalSince(sessionStartTime)
        let calories = estimatedCalories

        let record = ExerciseRecord(
            date: sessionStartTime,
            exerciseType: exercise.name,
            duration: duration,
            memo: String(memo.prefix(maxMemoLength)),
            exerciseDefinitionID: exercise.id,
            primaryMuscles: exercise.primaryMuscles,
            secondaryMuscles: exercise.secondaryMuscles,
            equipment: exercise.equipment,
            estimatedCalories: calories,
            calorieSource: .met
        )

        // Create WorkoutSet objects for completed sets
        var workoutSets: [WorkoutSet] = []
        for editableSet in completedSets {
            let trimmedWeight = editableSet.weight.trimmingCharacters(in: .whitespaces)
            let trimmedReps = editableSet.reps.trimmingCharacters(in: .whitespaces)
            let trimmedDuration = editableSet.duration.trimmingCharacters(in: .whitespaces)
            let trimmedDistance = editableSet.distance.trimmingCharacters(in: .whitespaces)
            let trimmedIntensity = editableSet.intensity.trimmingCharacters(in: .whitespaces)

            // Safe duration conversion with overflow guard
            let durationSeconds: TimeInterval? = Int(trimmedDuration).flatMap { mins in
                let secs = mins * 60
                guard secs / 60 == mins else { return nil } // overflow check
                return TimeInterval(secs)
            }

            // Convert weight from display unit to internal kg
            let weightKg: Double? = trimmedWeight.isEmpty ? nil : Double(trimmedWeight).map { weightUnit.toKg($0) }

            let workoutSet = WorkoutSet(
                setNumber: editableSet.setNumber,
                setType: editableSet.setType,
                weight: weightKg,
                reps: trimmedReps.isEmpty ? nil : Int(trimmedReps),
                duration: durationSeconds,
                distance: trimmedDistance.isEmpty ? nil : Double(trimmedDistance),
                intensity: trimmedIntensity.isEmpty ? nil : Int(trimmedIntensity),
                isCompleted: true
            )
            // Explicit bidirectional link for CloudKit reliability
            workoutSet.exerciseRecord = record
            workoutSets.append(workoutSet)
        }
        record.sets = workoutSets

        // Caller (View) must call didFinishSaving() after inserting into ModelContext
        return record
    }

    /// Call from View after successfully inserting record into ModelContext
    func didFinishSaving() {
        isSaving = false
    }
}
