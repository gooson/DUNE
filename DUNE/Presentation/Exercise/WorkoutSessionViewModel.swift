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
}

/// Previous session data for inline display
struct PreviousSetInfo: Sendable {
    let weight: Double?
    let reps: Int?
    let duration: TimeInterval?
    let distance: Double?
    let intensity: Int?
    let restDuration: TimeInterval?

    init(
        weight: Double?,
        reps: Int?,
        duration: TimeInterval?,
        distance: Double?,
        intensity: Int? = nil,
        restDuration: TimeInterval?
    ) {
        self.weight = weight
        self.reps = reps
        self.duration = duration
        self.distance = distance
        self.intensity = intensity
        self.restDuration = restDuration
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
    private let maxStairLevel = 30
    private let maxMemoLength = 500
    private let defaultRestSeconds: TimeInterval = WorkoutDefaults.restSeconds
    private let maxProgressiveIncreaseRatio = 0.10
    private let levelUpMinimumRepsAchievementRate = 0.9

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
        let profile = TemplateExerciseProfile(exercise: exercise)
        guard profile.showsStrengthDefaultsEditor else {
            templateRestDuration = nil
            return
        }

        templateRestDuration = entry.restDuration

        if let defaultWeightKg = entry.defaultWeightKg {
            let displayWeight = weightUnit.fromKg(defaultWeightKg)
            let weightString = displayWeight.formatted(.number.precision(.fractionLength(0...1)))
            for index in sets.indices {
                sets[index].weight = weightString
            }
        }

        guard usesDefaultReps else { return }
        let repsString = "\(entry.defaultReps)"
        for index in sets.indices {
            sets[index].reps = repsString
        }
    }

    // MARK: - Set Management

    func addSet(weightUnit: WeightUnit = .kg) {
        let newSetNumber = sets.count + 1
        var newSet = EditableSet(setNumber: newSetNumber)
        if usesDefaultReps {
            newSet.reps = "\(WorkoutDefaults.defaultReps)"
        }

        // Auto-fill from previous session if available
        let previousIndex = newSetNumber - 1
        if previousIndex < previousSets.count {
            let prev = previousSets[previousIndex]
            if let weight = prev.weight {
                let displayWeight = weightUnit.fromKg(weight)
                newSet.weight = displayWeight.formatted(.number.precision(.fractionLength(0...1)))
            }
            if let normalizedReps = normalizedRepsValue(from: prev.reps) {
                newSet.reps = "\(normalizedReps)"
            }
            if let duration = prev.duration {
                newSet.duration = "\(Int(duration / 60))"
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
            } else {
                newSet.reps = lastSet.reps
            }
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
        newSet.level = lastCompleted.level
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

    func loadPreviousSets(from records: [ExerciseRecord], weightUnit: WeightUnit = .kg) {
        guard !isSaving else { return }
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
                restDuration: set.restDuration
            )
        }

        // Match set count to previous session if it had more sets
        while sets.count < previousSets.count {
            addSet(weightUnit: weightUnit)
        }

        // Re-fill sets with previous data (init created sets before previousSets was loaded)
        for i in sets.indices where !sets[i].isCompleted {
            fillSetFromPrevious(at: i, weightUnit: weightUnit)
        }
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
        guard let prev = previousSetInfo(for: sets[index].setNumber) else { return }
        if let weight = prev.weight {
            let displayWeight = weightUnit.fromKg(weight)
            sets[index].weight = displayWeight.formatted(.number.precision(.fractionLength(0...1)))
        }
        if let normalizedReps = normalizedRepsValue(from: prev.reps) {
            sets[index].reps = "\(normalizedReps)"
        } else if usesDefaultReps {
            sets[index].reps = "\(WorkoutDefaults.defaultReps)"
        }
        if let duration = prev.duration {
            sets[index].duration = "\(Int(duration / 60))"
        }
        if let distance = prev.distance {
            sets[index].distance = distance.formatted(.number.precision(.fractionLength(0...2)))
        }
        if let intensity = prev.intensity {
            sets[index].level = "\(intensity)"
        }
    }

    /// Applies conservative progressive overload from the completed set to the next set.
    /// - Returns: true when the next-set weight was updated.
    @discardableResult
    func applyProgressiveOverloadForNextSet(afterCompletingSetAt index: Int, weightUnit: WeightUnit = .kg) -> Bool {
        let nextIndex = index + 1
        guard sets.indices.contains(index), sets.indices.contains(nextIndex) else { return false }

        let completed = sets[index]
        let completedWeightDisplay = Double(completed.weight.trimmingCharacters(in: .whitespaces))
        guard let completedWeightDisplay, completedWeightDisplay > 0 else { return false }

        let completedReps = normalizedRepsString(from: completed.reps).flatMap(Int.init)
        guard let completedReps else { return false }

        let targetReps = targetRepsForSet(at: index)
        guard completedReps >= targetReps else { return false }

        let currentWeightKg = weightUnit.toKg(completedWeightDisplay)
        let incrementKg = progressionIncrementKg
        let maxIncreaseKg = currentWeightKg * maxProgressiveIncreaseRatio
        let clampedIncreaseKg = min(incrementKg, max(maxIncreaseKg, 0))
        let proposedWeightKg = currentWeightKg + clampedIncreaseKg
        let roundedWeightKg = roundToPlateStepKg(proposedWeightKg)
        let nextDisplayWeight = weightUnit.fromKg(roundedWeightKg)
        let formatted = nextDisplayWeight.formatted(.number.precision(.fractionLength(0...1)))

        let isNextWeightEmpty = sets[nextIndex].weight.trimmingCharacters(in: .whitespaces).isEmpty
        if isNextWeightEmpty || sets[nextIndex].weight == completed.weight {
            sets[nextIndex].weight = formatted
            return true
        }
        return false
    }

    /// Level-up is suggested when all planned sets are completed and rep achievement rate reaches threshold.
    func shouldSuggestLevelUp() -> Bool {
        guard !sets.isEmpty else { return false }
        guard completedSetCount == sets.count else { return false }

        let completed = sets.filter(\.isCompleted)
        guard !completed.isEmpty else { return false }

        var achievedCount = 0
        for set in completed {
            let index = max(set.setNumber - 1, 0)
            guard let reps = normalizedRepsString(from: set.reps).flatMap(Int.init) else { continue }
            let target = targetRepsForSet(at: index)
            if reps >= target {
                achievedCount += 1
            }
        }

        let rate = Double(achievedCount) / Double(completed.count)
        return rate >= levelUpMinimumRepsAchievementRate
    }

    // MARK: - Per-Set Validation

    func validateSetForCompletion(at index: Int) -> Bool {
        guard sets.indices.contains(index) else { return false }

        let set = sets[index]
        if exercise.inputType == .setsRepsWeight || exercise.inputType == .setsReps {
            let trimmed = set.reps.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let reps = Int(trimmed), reps > 0, reps <= maxReps else {
                validationError = String(localized: "Reps must be between 1 and \(maxReps)")
                return false
            }
        }

        if exercise.inputType == .roundsBased {
            let trimmedReps = set.reps.trimmingCharacters(in: .whitespaces)
            guard !trimmedReps.isEmpty, let rounds = Int(trimmedReps), rounds > 0, rounds <= maxReps else {
                validationError = String(localized: "Rounds must be between 1 and \(maxReps)")
                return false
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
                level: set.level,
                isCompleted: set.isCompleted,
                setTypeRaw: set.setType.rawValue,
                restDuration: set.restDuration
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
            if exercise.inputType == .setsRepsWeight {
                let trimmed = set.weight.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    let maxDisplay = weightUnit.fromKg(maxWeightKg)
                    guard let weight = Double(trimmed), weight >= 0, weight <= maxDisplay else {
                        validationError = String(localized: "Weight must be between 0 and \(Int(maxDisplay))\(weightUnit.displayName)")
                        return nil
                    }
                }
            }
            if exercise.inputType == .durationDistance || exercise.inputType == .durationIntensity {
                let trimmed = set.duration.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    guard let mins = Int(trimmed), mins > 0, mins <= maxDurationMinutes else {
                        validationError = String(localized: "Duration must be between 1 and \(maxDurationMinutes) minutes")
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
            calorieSource: .met
        )

        // Create WorkoutSet objects for completed sets
        var workoutSets: [WorkoutSet] = []
        for editableSet in completedSets {
            let trimmedWeight = editableSet.weight.trimmingCharacters(in: .whitespaces)
            let trimmedReps = editableSet.reps.trimmingCharacters(in: .whitespaces)
            let trimmedDuration = editableSet.duration.trimmingCharacters(in: .whitespaces)
            let trimmedDistance = editableSet.distance.trimmingCharacters(in: .whitespaces)

            // Safe duration conversion with overflow guard
            let durationSeconds: TimeInterval? = Int(trimmedDuration).flatMap { mins in
                let secs = mins * 60
                guard secs / 60 == mins else { return nil } // overflow check
                return TimeInterval(secs)
            }

            // Convert weight from display unit to internal kg
            let weightKg: Double? = trimmedWeight.isEmpty ? nil : Double(trimmedWeight).map { weightUnit.toKg($0) }

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
                restDuration: editableSet.restDuration
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
        if isLowerBodyCompound {
            return 5.0
        }
        switch exercise.equipment {
        case .dumbbell:
            return 1.0
        case .kettlebell, .band, .trx, .medicineBall, .stabilityBall, .bodyweight, .other:
            return 1.0
        default:
            return 2.5
        }
    }

    private var isLowerBodyCompound: Bool {
        let lowerMuscles: Set<MuscleGroup> = [.quadriceps, .hamstrings, .glutes]
        return !Set(exercise.primaryMuscles).intersection(lowerMuscles).isEmpty
    }

    private func roundToPlateStepKg(_ value: Double) -> Double {
        let step = progressionIncrementKg <= 1.0 ? 1.0 : 2.5
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    private func targetRepsForSet(at index: Int) -> Int {
        if previousSets.indices.contains(index), let previousReps = normalizedRepsValue(from: previousSets[index].reps) {
            return previousReps
        }
        if sets.indices.contains(index), let currentReps = normalizedRepsString(from: sets[index].reps).flatMap(Int.init) {
            return currentReps
        }
        return WorkoutDefaults.defaultReps
    }
}
