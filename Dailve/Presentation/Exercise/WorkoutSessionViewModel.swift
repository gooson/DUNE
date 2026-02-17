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

    func addSet() {
        let newSetNumber = sets.count + 1
        var newSet = EditableSet(setNumber: newSetNumber)

        // Auto-fill from previous session if available
        let previousIndex = newSetNumber - 1
        if previousIndex < previousSets.count {
            let prev = previousSets[previousIndex]
            if let weight = prev.weight {
                newSet.weight = weight.formatted(.number.precision(.fractionLength(0...1)))
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
        let completedCount = sets.filter(\.isCompleted).count
        let restSets = max(completedCount - 1, 0)
        return Double(restSets) * defaultRestSeconds
    }

    // MARK: - Summary

    var completedSetCount: Int {
        sets.filter(\.isCompleted).count
    }

    var weightRange: String? {
        let weights = sets.filter(\.isCompleted).compactMap { Double($0.weight) }.filter { $0 > 0 }
        guard !weights.isEmpty else { return nil }
        let minW = weights.min() ?? 0
        let maxW = weights.max() ?? 0
        if minW == maxW {
            return minW.formatted(.number.precision(.fractionLength(0...1))) + "kg"
        }
        return "\(minW.formatted(.number.precision(.fractionLength(0...1))))-\(maxW.formatted(.number.precision(.fractionLength(0...1))))kg"
    }

    var totalReps: Int {
        sets.filter(\.isCompleted).compactMap { Int($0.reps) }.reduce(0, +)
    }

    // MARK: - Validation & Record Creation

    func createValidatedRecord() -> ExerciseRecord? {
        guard !isSaving else { return nil }
        validationError = nil

        let completedSets = sets.filter(\.isCompleted)
        guard !completedSets.isEmpty else {
            validationError = "Complete at least one set"
            return nil
        }

        // Validate each completed set
        for set in completedSets {
            if exercise.inputType == .setsRepsWeight || exercise.inputType == .setsReps {
                guard let reps = Int(set.reps), reps > 0, reps <= maxReps else {
                    validationError = "Reps must be between 1 and \(maxReps)"
                    return nil
                }
            }
            if exercise.inputType == .setsRepsWeight {
                if !set.weight.isEmpty {
                    guard let weight = Double(set.weight), weight >= 0, weight <= maxWeightKg else {
                        validationError = "Weight must be between 0 and \(Int(maxWeightKg))kg"
                        return nil
                    }
                }
            }
            if exercise.inputType == .durationDistance || exercise.inputType == .durationIntensity {
                if !set.duration.isEmpty {
                    guard let mins = Int(set.duration), mins > 0, mins <= maxDurationMinutes else {
                        validationError = "Duration must be between 1 and \(maxDurationMinutes) minutes"
                        return nil
                    }
                }
            }
            if exercise.inputType == .durationDistance {
                if !set.distance.isEmpty {
                    guard let dist = Double(set.distance), dist > 0, dist <= maxDistanceKm else {
                        validationError = "Distance must be between 0.1 and \(Int(maxDistanceKm))km"
                        return nil
                    }
                }
            }
            if exercise.inputType == .durationIntensity {
                if !set.intensity.isEmpty {
                    guard let val = Int(set.intensity), val >= 1, val <= maxIntensity else {
                        validationError = "Intensity must be between 1 and \(maxIntensity)"
                        return nil
                    }
                }
            }
            if exercise.inputType == .roundsBased {
                guard let reps = Int(set.reps), reps > 0, reps <= maxReps else {
                    validationError = "Rounds must be between 1 and \(maxReps)"
                    return nil
                }
                if !set.duration.isEmpty {
                    guard let secs = Int(set.duration), secs > 0 else {
                        validationError = "Duration must be greater than 0"
                        return nil
                    }
                }
            }
        }

        isSaving = true
        defer { isSaving = false }

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
        // SwiftData handles inverse relationship via @Relationship
        var workoutSets: [WorkoutSet] = []
        for editableSet in completedSets {
            let workoutSet = WorkoutSet(
                setNumber: editableSet.setNumber,
                setType: editableSet.setType,
                weight: Double(editableSet.weight),
                reps: Int(editableSet.reps),
                duration: Int(editableSet.duration).map { TimeInterval($0 * 60) },
                distance: Double(editableSet.distance),
                intensity: Int(editableSet.intensity),
                isCompleted: true
            )
            workoutSets.append(workoutSet)
        }
        record.sets = workoutSets

        return record
    }
}
