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
    var level: String = ""
    var isCompleted: Bool = false
    var setType: SetType = .working
    /// Rest timer total (including +30s adjustments) used after this set, in seconds.
    var restDuration: TimeInterval?
    /// Set-level RPE (6.0-10.0, 0.5 step). Nil if not rated.
    var rpe: Double?
    /// Planned reps stay fixed when performed reps are edited. Nil for unknown legacy plans.
    var plannedReps: Int?
    /// `user` or `estimated`; nil means the origin is unknown.
    var rpeSourceRaw: String?
}

/// Previous session data for inline display
struct PreviousSetInfo: Sendable {
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let distance: Double?
    let intensity: Int?
    let restDuration: TimeInterval?
    let plannedReps: Int?
    let rpe: Double?
    let rpeSourceRaw: String?
    let setType: SetType

    init(
        weight: Double?,
        reps: Int?,
        duration: TimeInterval?,
        distance: Double?,
        intensity: Int? = nil,
        restDuration: TimeInterval?,
        plannedReps: Int? = nil,
        rpe: Double? = nil,
        rpeSourceRaw: String? = nil,
        setType: SetType = .working
    ) {
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.distance = distance
        self.intensity = intensity
        self.restDuration = restDuration
        self.plannedReps = plannedReps
        self.rpe = rpe
        self.rpeSourceRaw = rpeSourceRaw
        self.setType = setType
    }
}

// MARK: - Draft Persistence

/// Codable snapshot of a workout session for background/crash recovery
struct WorkoutSessionDraft: Codable {
    let exerciseDefinition: ExerciseDefinition
    let sets: [DraftSet]
    let sessionStartTime: Date
    let memo: String
    let savedAt: Date
    var templateRestDuration: TimeInterval?

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
        var plannedReps: Int? = nil
        var rpe: Double? = nil
        var rpeSourceRaw: String? = nil
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

    /// Per-set timer start dates for durationIntensity exercises.
    var setTimerStarts: [UUID: Date] = [:]

    var isSaving = false
    var validationError: String?

    private let calorieService: CalorieEstimating
    private let maxWeightKg = 500.0
    private let maxReps = 1000
    private let maxDurationMinutes = 500
    private let maxStairLevel = 30
    private let maxMemoLength = 500
    private let defaultRestSeconds: TimeInterval = WorkoutDefaults.restSeconds
    private let progressionService = WorkoutProgressionService()
    private var currentWeightUnit: WeightUnit = .kg

    private struct RecommendationContext {
        let targetID: UUID
        let targetWeight: String
        let targetPlannedReps: Int?
        let targetSetType: SetType
        let sourceID: UUID?
        let sourceWeight: String?
        let sourceReps: String?
        let sourcePlannedReps: Int?
        let sourceRPE: Double?
        let sourceRPESourceRaw: String?
        let sourceSetType: SetType?
        let unit: WeightUnit
    }

    private var recommendationContext: RecommendationContext?
    private var restoredFromDraft = false
    private(set) var pendingWeightRecommendation: WeightRecommendation?
    private(set) var recommendationSetIndex: Int?

    /// Body weight for calorie estimation (fetched externally, uses store default)
    var bodyWeightKg: Double = WorkoutDefaults.bodyWeightKg

    /// Per-exercise rest duration override from the template entry (nil = use global).
    var templateRestDuration: TimeInterval?

    init(
        exercise: ExerciseDefinition,
        defaultSetCount: Int? = nil,
        calorieService: CalorieEstimating = CalorieEstimationService()
    ) {
        self.exercise = exercise
        self.calorieService = calorieService
        let setCount = defaultSetCount ?? WorkoutDefaults.setCount
        for _ in 0..<setCount {
            addSet()
        }
    }

    func applyTemplateDefaults(_ entry: TemplateEntry, weightUnit: WeightUnit = .kg) {
        currentWeightUnit = weightUnit
        guard !restoredFromDraft else { return }
        let profile = TemplateExerciseProfile(exercise: exercise)
        guard profile.showsStrengthDefaultsEditor else {
            templateRestDuration = nil
            return
        }

        templateRestDuration = entry.restDuration

        if supportsWeight, let defaultWeightKg = entry.defaultWeightKg {
            let displayWeight = weightUnit.fromKg(defaultWeightKg)
            let weightString = formattedEditableWeight(displayWeight)
            for index in sets.indices {
                sets[index].weight = weightString
            }
        }

        guard usesDefaultReps else { return }
        let repsString = "\(entry.defaultReps)"
        for index in sets.indices {
            sets[index].reps = repsString
            sets[index].plannedReps = normalizedRepsValue(from: entry.defaultReps)
        }
    }

    // MARK: - Set Management

    func addSet(weightUnit: WeightUnit = .kg) {
        currentWeightUnit = weightUnit
        let newSetNumber = sets.count + 1
        var newSet = EditableSet(setNumber: newSetNumber)
        if usesDefaultReps {
            newSet.reps = "\(WorkoutDefaults.defaultReps)"
            newSet.plannedReps = WorkoutDefaults.defaultReps
        }

        // Auto-fill from previous session if available
        let previousIndex = newSetNumber - 1
        if previousIndex < previousSets.count {
            let prev = previousSets[previousIndex]
            newSet.setType = prev.setType
            if supportsWeight, let weight = prev.weight {
                let displayWeight = weightUnit.fromKg(weight)
                newSet.weight = formattedEditableWeight(displayWeight)
            }
            if let normalizedReps = normalizedRepsValue(from: prev.reps) {
                newSet.reps = "\(normalizedReps)"
            }
            newSet.plannedReps = normalizedRepsValue(from: prev.plannedReps)
                ?? normalizedRepsValue(from: prev.reps)
            if let duration = prev.duration {
                newSet.duration = "\(Int(exercise.inputType == .durationIntensity || exercise.inputType == .roundsBased ? duration : duration / 60))"
            }
            if let distance = prev.distance {
                newSet.distance = distance.formatted(.number.precision(.fractionLength(0...2)))
            }
            if let intensity = prev.intensity {
                newSet.level = "\(intensity)"
            }
        }
        // If no previous data, auto-fill from last current set
        else if let lastSet = sets.last {
            newSet.weight = lastSet.weight
            if usesDefaultReps {
                let normalized = normalizedRepsString(from: lastSet.reps)
                newSet.reps = normalized ?? "\(WorkoutDefaults.defaultReps)"
                newSet.plannedReps = lastSet.plannedReps
            } else {
                newSet.reps = lastSet.reps
            }
            newSet.duration = lastSet.duration
            newSet.distance = lastSet.distance
        }

        sets.append(newSet)
        startTimerIfNeeded(for: newSet)
    }

    /// Creates a new set pre-filled with the last completed set's values.
    func repeatLastCompletedSet() {
        guard let lastCompleted = sets.last(where: \.isCompleted) else { return }
        let newSetNumber = sets.count + 1
        var newSet = EditableSet(setNumber: newSetNumber)
        newSet.weight = lastCompleted.weight
        newSet.reps = lastCompleted.reps
        newSet.plannedReps = lastCompleted.plannedReps
        newSet.duration = lastCompleted.duration
        newSet.distance = lastCompleted.distance
        newSet.level = lastCompleted.level
        sets.append(newSet)
        startTimerIfNeeded(for: newSet)
    }

    /// Starts a live timer for the set if the exercise uses durationIntensity input.
    private func startTimerIfNeeded(for set: EditableSet) {
        guard exercise.inputType == .durationIntensity else { return }
        setTimerStarts[set.id] = Date()
    }

    /// Stops the timer for the given set and records elapsed seconds.
    /// Returns the elapsed duration in seconds, or nil if no timer was running or elapsed < 1s.
    /// Keeps the start date in the dictionary until a valid duration is confirmed
    /// to prevent double-tap from losing the timer reference.
    func stopTimer(for set: EditableSet) -> TimeInterval? {
        guard let start = setTimerStarts[set.id] else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed >= 1 else { return nil }
        setTimerStarts.removeValue(forKey: set.id)
        return elapsed
    }

    var hasCompletedSet: Bool {
        sets.contains(where: \.isCompleted)
    }

    func removeSet(at index: Int) {
        guard sets.indices.contains(index) else { return }
        clearRecommendation()
        sets.remove(at: index)
        // Renumber remaining sets
        for i in sets.indices {
            sets[i].setNumber = i + 1
        }
    }

    func toggleSetCompletion(at index: Int) -> Bool {
        guard sets.indices.contains(index) else { return false }
        clearRecommendation()
        sets[index].isCompleted.toggle()
        return sets[index].isCompleted
    }

    // MARK: - Previous Session

    func loadPreviousSets(from records: [ExerciseRecord], weightUnit: WeightUnit = .kg) {
        guard !isSaving else { return }
        currentWeightUnit = weightUnit
        clearRecommendation()
        let exactMatches = records
            .filter { $0.exerciseDefinitionID == exercise.id }
            .sorted { $0.date > $1.date }

        let matching: [ExerciseRecord]
        if !exactMatches.isEmpty {
            matching = exactMatches
        } else if let targetCanonical = QuickStartCanonicalService.canonicalKey(
            exerciseID: exercise.id,
            exerciseName: exercise.localizedName
        ) {
            matching = records
                .filter { record in
                    let recordCanonical = QuickStartCanonicalService.canonicalKey(
                        exerciseID: record.exerciseDefinitionID,
                        exerciseName: record.exerciseType
                    )
                    return recordCanonical == targetCanonical
                }
                .sorted { $0.date > $1.date }
        } else {
            matching = []
        }

        guard let lastSession = matching.first else {
            previousSets = []
            return
        }

        previousSets = lastSession.completedSets.map { set in
            PreviousSetInfo(
                weight: set.weight,
                reps: set.reps,
                duration: set.duration,
                distance: set.distance,
                intensity: set.intensity,
                restDuration: set.restDuration,
                plannedReps: set.plannedReps,
                rpe: set.rpe,
                rpeSourceRaw: set.rpeSourceRaw,
                setType: set.setType
            )
        }

        // A restored draft is already the source of truth for every editable field.
        guard !restoredFromDraft else { return }

        // Match set count to previous session if it had more sets
        while sets.count < previousSets.count {
            addSet(weightUnit: weightUnit)
        }

        // Re-fill sets with previous data (init created sets before previousSets was loaded)
        for i in sets.indices where !sets[i].isCompleted {
            fillSetFromPrevious(at: i, weightUnit: weightUnit)
        }

        guard supportsWeight,
              let firstWorkingIndex = previousSets.firstIndex(where: { $0.setType == .working }),
              sets.indices.contains(firstWorkingIndex),
              !sets[firstWorkingIndex].isCompleted,
              sets[firstWorkingIndex].setType == .working else { return }
        let priorInputs = previousSets.map { previous in
            ProgressionSetInput(
                weight: previous.weight, reps: previous.reps,
                plannedReps: previous.plannedReps, rpe: previous.rpe,
                rpeSourceRaw: previous.rpeSourceRaw, setType: previous.setType,
                isCompleted: true
            )
        }
        let recommendation = progressionService.nextSession(
            sets: priorInputs,
            plannedSetCount: lastSession.plannedSetCount,
            incrementKg: progressionIncrementKg
        )
        setRecommendation(recommendation, for: firstWorkingIndex, sourceIndex: nil, unit: weightUnit)
    }

    func previousSetInfo(for setNumber: Int) -> PreviousSetInfo? {
        let index = setNumber - 1
        guard index >= 0, index < previousSets.count else { return nil }
        return previousSets[index]
    }

    /// Resolves rest timer duration for the set at `index`.
    /// Priority: previous session → template entry → global default.
    /// Values are clamped to 1...3600 to guard against corrupted data from CloudKit/drafts.
    func resolveRestDuration(forSetAt index: Int) -> TimeInterval {
        guard sets.indices.contains(index) else { return defaultRestSeconds }
        let setNumber = sets[index].setNumber
        if let prevRest = previousSetInfo(for: setNumber)?.restDuration,
           prevRest.isFinite, prevRest > 0 {
            return Swift.min(prevRest, 3600)
        }
        if let templateRest = templateRestDuration,
           templateRest.isFinite, templateRest > 0 {
            return Swift.min(templateRest, 3600)
        }
        return defaultRestSeconds
    }

    func fillSetFromPrevious(at index: Int, weightUnit: WeightUnit = .kg) {
        guard sets.indices.contains(index) else { return }
        currentWeightUnit = weightUnit
        guard let prev = previousSetInfo(for: sets[index].setNumber) else { return }
        sets[index].setType = prev.setType
        if supportsWeight, let weight = prev.weight {
            let displayWeight = weightUnit.fromKg(weight)
            sets[index].weight = formattedEditableWeight(displayWeight)
        } else {
            sets[index].weight = ""
        }
        if let normalizedReps = normalizedRepsValue(from: prev.reps) {
            sets[index].reps = "\(normalizedReps)"
        } else if usesDefaultReps {
            sets[index].reps = "\(WorkoutDefaults.defaultReps)"
        }
        sets[index].plannedReps = normalizedRepsValue(from: prev.plannedReps)
            ?? normalizedRepsValue(from: prev.reps)
        if let duration = prev.duration {
            sets[index].duration = "\(Int(exercise.inputType == .durationIntensity || exercise.inputType == .roundsBased ? duration : duration / 60))"
        }
        if let distance = prev.distance {
            sets[index].distance = distance.formatted(.number.precision(.fractionLength(0...2)))
        }
        if let intensity = prev.intensity {
            sets[index].level = "\(intensity)"
        }
    }

    /// Offers the shared within-session recommendation without changing entered weights.
    func prepareNextSetRecommendation(afterCompletingSetAt index: Int, weightUnit: WeightUnit = .kg) {
        currentWeightUnit = weightUnit
        clearRecommendation()
        let nextIndex = index + 1
        guard supportsWeight, sets.indices.contains(index), sets.indices.contains(nextIndex),
              !sets[nextIndex].isCompleted,
              sets[nextIndex].setType == .working else { return }
        let completed = sets[index]
        let recommendation = progressionService.nextSet(
            after: progressionInput(for: completed, unit: weightUnit),
            incrementKg: progressionIncrementKg
        )
        setRecommendation(recommendation, for: nextIndex, sourceIndex: index, unit: weightUnit)
    }

    /// Applies a pending recommendation only while its source and destination remain unchanged.
    @discardableResult
    func applyWeightRecommendation(weightUnit: WeightUnit = .kg) -> Bool {
        guard let recommendation = pendingWeightRecommendation,
              let index = recommendationSetIndex,
              let context = recommendationContext,
              sets.indices.contains(index),
              !sets[index].isCompleted,
              sets[index].id == context.targetID,
              sets[index].weight == context.targetWeight,
              sets[index].plannedReps == context.targetPlannedReps,
              sets[index].setType == context.targetSetType,
              weightUnit == context.unit,
              recommendation.weight.isFinite,
              recommendation.weight > 0,
              recommendation.weight <= maxWeightKg else {
            clearRecommendation()
            return false
        }
        if let sourceID = context.sourceID {
            let sourceIndex = index - 1
            guard sets.indices.contains(sourceIndex) else {
                clearRecommendation()
                return false
            }
            let source = sets[sourceIndex]
            guard source.id == sourceID, source.isCompleted,
                  source.weight == context.sourceWeight,
                  source.reps == context.sourceReps,
                  source.plannedReps == context.sourcePlannedReps,
                  source.rpe == context.sourceRPE,
                  source.rpeSourceRaw == context.sourceRPESourceRaw,
                  source.setType == context.sourceSetType else {
                clearRecommendation()
                return false
            }
        }
        sets[index].weight = formattedEditableWeight(weightUnit.fromKg(recommendation.weight))
        clearRecommendation()
        return true
    }

    private func setRecommendation(
        _ recommendation: WeightRecommendation?,
        for index: Int,
        sourceIndex: Int?,
        unit: WeightUnit
    ) {
        guard let recommendation, sets.indices.contains(index) else { return }
        let source = sourceIndex.flatMap { sets.indices.contains($0) ? sets[$0] : nil }
        recommendationContext = RecommendationContext(
            targetID: sets[index].id,
            targetWeight: sets[index].weight,
            targetPlannedReps: sets[index].plannedReps,
            targetSetType: sets[index].setType,
            sourceID: source?.id,
            sourceWeight: source?.weight,
            sourceReps: source?.reps,
            sourcePlannedReps: source?.plannedReps,
            sourceRPE: source?.rpe,
            sourceRPESourceRaw: source?.rpeSourceRaw,
            sourceSetType: source?.setType,
            unit: unit
        )
        pendingWeightRecommendation = recommendation
        recommendationSetIndex = index
    }

    private func clearRecommendation() {
        pendingWeightRecommendation = nil
        recommendationSetIndex = nil
        recommendationContext = nil
    }

    private func progressionInput(for set: EditableSet, unit: WeightUnit) -> ProgressionSetInput {
        let displayWeight = Double(set.weight.trimmingCharacters(in: .whitespaces))
        let weightKg = displayWeight.map { unit.toKg($0) }
        let reps = normalizedRepsString(from: set.reps).flatMap(Int.init)
        return ProgressionSetInput(
            weight: weightKg, reps: reps, plannedReps: set.plannedReps,
            rpe: set.rpe, rpeSourceRaw: set.rpeSourceRaw,
            setType: set.setType, isCompleted: set.isCompleted
        )
    }

    // MARK: - Level-Up Suggestion

    /// True when the shared policy can increase a fully completed planned session.
    var shouldSuggestLevelUp: Bool {
        guard supportsWeight, !sets.isEmpty, completedSetCount == sets.count else { return false }
        let recommendation = progressionService.nextSession(
            sets: sets.map { progressionInput(for: $0, unit: currentWeightUnit) },
            plannedSetCount: sets.count,
            incrementKg: progressionIncrementKg
        )
        return recommendation?.reason == .readyToProgress
    }

    // MARK: - Per-Set Validation

    func validateSetForCompletion(at index: Int, weightUnit: WeightUnit = .kg) -> Bool {
        guard sets.indices.contains(index) else { return false }

        let set = sets[index]
        if exercise.inputType == .setsRepsWeight || exercise.inputType == .setsReps {
            let trimmed = set.reps.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let reps = Int(trimmed), reps > 0, reps <= maxReps else {
                validationError = String(localized: "Reps must be between 1 and \(maxReps)")
                return false
            }
        }

        if supportsWeight {
            let trimmed = set.weight.trimmingCharacters(in: .whitespaces)
            let maxDisplay = weightUnit.fromKg(maxWeightKg)
            if !trimmed.isEmpty {
                guard let weight = Double(trimmed), weight.isFinite, (0...maxDisplay).contains(weight) else {
                    validationError = String(localized: "Weight must be between 0 and \(Int(maxDisplay))\(weightUnit.displayName)")
                    return false
                }
            }
        }

        if exercise.inputType == .roundsBased {
            let trimmedReps = set.reps.trimmingCharacters(in: .whitespaces)
            guard !trimmedReps.isEmpty, let rounds = Int(trimmedReps), rounds > 0, rounds <= maxReps else {
                validationError = String(localized: "Rounds must be between 1 and \(maxReps)")
                return false
            }
        }

        if exercise.inputType == .durationIntensity || exercise.inputType == .roundsBased {
            let trimmed = set.duration.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let maximum = exercise.inputType == .durationIntensity ? 7200 : maxDurationMinutes * 60
                guard let seconds = Int(trimmed), (1...maximum).contains(seconds) else {
                    validationError = exercise.inputType == .durationIntensity
                        ? String(localized: "Duration must be between 1 second and 2 hours")
                        : String(localized: "Duration must be between 1 and \(maxDurationMinutes * 60) seconds")
                    return false
                }
            }
        }

        validationError = nil
        return true
    }

    // MARK: - Calorie Estimation

    var estimatedCalories: Double? {
        let totalDuration = sessionDurationSeconds
        let totalRest = totalRestSeconds
        return calorieService.estimate(
            metValue: adjustedMETForStairLevel,
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

    // MARK: - Summary

    // Completed rows remain editable; always read their current values when saving.
    private var cachedCompletedSets: [EditableSet] {
        sets.filter(\.isCompleted)
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
                level: set.level,
                isCompleted: set.isCompleted,
                setTypeRaw: set.setType.rawValue,
                restDuration: set.restDuration,
                plannedReps: set.plannedReps,
                rpe: set.rpe,
                rpeSourceRaw: set.rpeSourceRaw
            )
        }
        let draft = WorkoutSessionDraft(
            exerciseDefinition: exercise,
            sets: draftSets,
            sessionStartTime: sessionStartTime,
            memo: memo,
            savedAt: Date(),
            templateRestDuration: templateRestDuration
        )
        WorkoutSessionDraft.save(draft)
    }

    func restoreFromDraft(_ draft: WorkoutSessionDraft) {
        clearRecommendation()
        restoredFromDraft = true
        sessionStartTime = draft.sessionStartTime
        memo = draft.memo
        templateRestDuration = draft.templateRestDuration
        sets = draft.sets.map { draftSet in
            var editable = EditableSet(setNumber: draftSet.setNumber)
            editable.weight = draftSet.weight
            editable.reps = draftSet.reps
            editable.duration = draftSet.duration
            editable.distance = draftSet.distance
            editable.level = draftSet.level ?? ""
            editable.isCompleted = draftSet.isCompleted
            editable.setType = SetType(rawValue: draftSet.setTypeRaw) ?? .working
            editable.restDuration = draftSet.restDuration
            editable.plannedReps = normalizedRepsValue(from: draftSet.plannedReps)
            editable.rpe = draftSet.rpe.flatMap(RPELevel.validate)
            editable.rpeSourceRaw = draftSet.rpeSourceRaw
            return editable
        }
    }

    /// Shared by compound/template draft restoration, which restores each exercise separately.
    func markDraftRestored() {
        restoredFromDraft = true
        clearRecommendation()
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
            validationError = String(localized: "Complete at least one set")
            return nil
        }

        // Validate each completed set
        for set in completedSets {
            if exercise.inputType == .setsRepsWeight || exercise.inputType == .setsReps {
                let trimmed = set.reps.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, let reps = Int(trimmed), reps > 0, reps <= maxReps else {
                    validationError = String(localized: "Reps must be between 1 and \(maxReps)")
                    return nil
                }
            }
            if supportsWeight {
                let trimmed = set.weight.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let maxDisplay = weightUnit.fromKg(maxWeightKg)
                    guard let weight = Double(trimmed), weight >= 0, weight <= maxDisplay else {
                        validationError = String(localized: "Weight must be between 0 and \(Int(maxDisplay))\(weightUnit.displayName)")
                        return nil
                    }
                }
            }
            if exercise.inputType == .durationDistance {
                let trimmed = set.duration.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    guard let mins = Int(trimmed), mins > 0, mins <= maxDurationMinutes else {
                        validationError = String(localized: "Duration must be between 1 and \(maxDurationMinutes) minutes")
                        return nil
                    }
                }
            }
            if exercise.inputType == .durationIntensity {
                let trimmed = set.duration.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    guard let secs = Int(trimmed), secs >= 1, secs <= 7200 else {
                        validationError = String(localized: "Duration must be between 1 second and 2 hours")
                        return nil
                    }
                }
            }
            if exercise.inputType == .durationDistance {
                let unit = exercise.cardioSecondaryUnit ?? .km
                if unit.usesDistanceField {
                    // Empty distance is intentionally permitted — user may log a time-only session
                    // (e.g., swim without tracking distance). Stored as nil distance.
                    let trimmed = set.distance.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty, let range = unit.validationRange {
                        guard let dist = Double(trimmed), range.contains(dist) else {
                            let lo = range.lowerBound.formatted(.number.precision(.fractionLength(0...1)))
                            validationError = String(localized: "\(unit.placeholder.capitalized) must be between \(lo) and \(Int(range.upperBound))")
                            return nil
                        }
                    }
                } else if unit.usesRepsField {
                    let trimmed = set.reps.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty, let range = unit.validationRange {
                        guard let val = Int(trimmed), Double(val) >= range.lowerBound, Double(val) <= range.upperBound else {
                            validationError = String(localized: "\(unit.placeholder.capitalized) must be between \(Int(range.lowerBound)) and \(Int(range.upperBound))")
                            return nil
                        }
                    }
                }
                if unit == .floors {
                    let trimmedLevel = set.level.trimmingCharacters(in: .whitespaces)
                    if !trimmedLevel.isEmpty {
                        guard let level = Int(trimmedLevel), (1...maxStairLevel).contains(level) else {
                            validationError = String(localized: "Level must be between 1 and \(maxStairLevel)")
                            return nil
                        }
                    }
                }
                // unit == .timeOnly → no secondary field validation needed
            }
            if exercise.inputType == .roundsBased {
                let trimmedReps = set.reps.trimmingCharacters(in: .whitespaces)
                guard !trimmedReps.isEmpty, let reps = Int(trimmedReps), reps > 0, reps <= maxReps else {
                    validationError = String(localized: "Rounds must be between 1 and \(maxReps)")
                    return nil
                }
                let trimmedDur = set.duration.trimmingCharacters(in: .whitespaces)
                if !trimmedDur.isEmpty {
                    guard let secs = Int(trimmedDur), secs > 0, secs <= maxDurationMinutes * 60 else {
                        validationError = String(localized: "Duration must be between 1 and \(maxDurationMinutes * 60) seconds")
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
            calorieSource: .met,
            plannedSetCount: sets.count
        )

        // Create WorkoutSet objects for completed sets
        var workoutSets: [WorkoutSet] = []
        for editableSet in completedSets {
            let trimmedWeight = editableSet.weight.trimmingCharacters(in: .whitespaces)
            let trimmedReps = editableSet.reps.trimmingCharacters(in: .whitespaces)
            let trimmedDuration = editableSet.duration.trimmingCharacters(in: .whitespaces)
            let trimmedDistance = editableSet.distance.trimmingCharacters(in: .whitespaces)

            // Safe duration conversion with overflow guard
            let durationSeconds: TimeInterval?
            if exercise.inputType == .durationIntensity || exercise.inputType == .roundsBased {
                // Timed sets and rounds store seconds.
                durationSeconds = Int(trimmedDuration).map { TimeInterval($0) }
            } else {
                // Other types store minutes
                durationSeconds = Int(trimmedDuration).flatMap { mins in
                    let secs = mins * 60
                    guard secs / 60 == mins else { return nil } // overflow check
                    return TimeInterval(secs)
                }
            }

            // Convert weight from display unit to internal kg
            let parsedWeightKg = !supportsWeight || trimmedWeight.isEmpty
                ? nil : Double(trimmedWeight).map { weightUnit.toKg($0) }
            let weightKg = exercise.inputType == .setsReps && parsedWeightKg == 0 ? nil : parsedWeightKg

            // Convert distance based on cardio secondary unit
            let distanceKm: Double?
            let repsValue: Int?
            let levelValue: Int?

            if exercise.inputType == .durationDistance {
                let unit = exercise.cardioSecondaryUnit ?? .km
                if unit.usesDistanceField {
                    distanceKm = Double(trimmedDistance).flatMap { unit.toKm($0) }
                    repsValue = nil
                } else if unit.usesRepsField {
                    distanceKm = nil
                    repsValue = trimmedReps.isEmpty ? nil : Int(trimmedReps)
                } else {
                    // .timeOnly — no secondary field
                    distanceKm = nil
                    repsValue = nil
                }
                levelValue = unit == .floors ? Int(editableSet.level.trimmingCharacters(in: .whitespaces)) : nil
            } else {
                distanceKm = trimmedDistance.isEmpty ? nil : Double(trimmedDistance)
                repsValue = trimmedReps.isEmpty ? nil : Int(trimmedReps)
                levelValue = nil
            }

            let workoutSet = WorkoutSet(
                setNumber: editableSet.setNumber,
                setType: editableSet.setType,
                weight: weightKg,
                reps: repsValue,
                duration: durationSeconds,
                distance: distanceKm,
                intensity: levelValue,
                isCompleted: true,
                restDuration: editableSet.restDuration,
                rpe: editableSet.rpe.flatMap(RPELevel.validate),
                plannedReps: usesDefaultReps ? normalizedRepsValue(from: editableSet.plannedReps) : nil,
                rpeSourceRaw: editableSet.rpe.flatMap(RPELevel.validate) == nil
                    ? nil : editableSet.rpeSourceRaw
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

    var supportsWeight: Bool {
        exercise.inputType == .setsRepsWeight || exercise.inputType == .setsReps
    }

    /// Convert every entered set, including completed rows, before changing the display unit.
    /// Invalid text is left intact so validation can report it rather than silently discard it.
    func convertWeightUnit(from oldUnit: WeightUnit, to newUnit: WeightUnit) {
        guard oldUnit != newUnit else { return }
        clearRecommendation()
        currentWeightUnit = newUnit
        for index in sets.indices {
            let trimmed = sets[index].weight.trimmingCharacters(in: .whitespaces)
            guard let value = Double(trimmed), value.isFinite else { continue }
            let converted = newUnit.fromKg(oldUnit.toKg(value))
            sets[index].weight = converted.formatted(
                .number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(0...4))
            )
        }
    }

    private var usesDefaultReps: Bool {
        exercise.inputType == .setsRepsWeight || exercise.inputType == .setsReps
    }

    private var adjustedMETForStairLevel: Double {
        guard exercise.cardioSecondaryUnit == .floors else { return exercise.metValue }
        let levels = sets.compactMap { set -> Int? in
            let trimmed = set.level.trimmingCharacters(in: .whitespaces)
            guard let level = Int(trimmed), (1...maxStairLevel).contains(level) else { return nil }
            return level
        }
        guard !levels.isEmpty else { return exercise.metValue }
        let averageLevel = Double(levels.reduce(0, +)) / Double(levels.count)
        let multiplier = min(max(averageLevel / 5.0, 0.5), 2.0)
        return exercise.metValue * multiplier
    }

    private func normalizedRepsValue(from value: Int?) -> Int? {
        guard let value, value > 0, value <= maxReps else { return nil }
        return value
    }

    private func normalizedRepsString(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let reps = Int(trimmed), reps > 0, reps <= maxReps else { return nil }
        return "\(reps)"
    }

    private var progressionIncrementKg: Double {
        WorkoutProgressionService.incrementKg(
            equipment: exercise.equipment,
            primaryMuscles: exercise.primaryMuscles
        )
    }

    private func formattedEditableWeight(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
            .grouping(.never).precision(.fractionLength(0...1)))
    }

}
