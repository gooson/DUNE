import Foundation
import Observation

/// ViewModel for CardioSessionView — manages session lifecycle and record creation.
/// Follows the `createValidatedRecord() -> ExerciseRecord?` pattern (input-validation.md).
@Observable
@MainActor
final class CardioSessionViewModel {
    let exercise: ExerciseDefinition
    let isOutdoor: Bool
    let sessionManager: CardioSessionManager

    var isSaving = false
    var validationError: String?

    init(
        exercise: ExerciseDefinition,
        isOutdoor: Bool,
        sessionManager: CardioSessionManager = CardioSessionManager()
    ) {
        self.exercise = exercise
        self.isOutdoor = isOutdoor
        self.sessionManager = sessionManager
    }

    // MARK: - Session Lifecycle

    func startSession() async {
        let activityType = WorkoutActivityType.resolveDistanceBased(
            from: exercise.id,
            name: exercise.name
        ) ?? exercise.resolvedActivityType

        do {
            try await sessionManager.startSession(activityType: activityType, isOutdoor: isOutdoor)
        } catch {
            validationError = String(localized: "Unable to start workout session")
            AppLogger.healthKit.error("Failed to start cardio session: \(error.localizedDescription)")
        }
    }

    func pauseSession() {
        sessionManager.pause()
    }

    func resumeSession() {
        sessionManager.resume()
    }

    func endSession() async {
        await sessionManager.endSession()
    }

    // MARK: - Record Creation

    /// Creates an ExerciseRecord from the completed cardio session.
    /// Returns nil if session has no meaningful data.
    func createValidatedRecord() -> ExerciseRecord? {
        guard !isSaving else { return nil }
        validationError = nil

        let elapsed = sessionManager.elapsedTime
        guard elapsed > 0 else {
            validationError = String(localized: "No workout data to save")
            return nil
        }

        isSaving = true

        let distanceKm = sessionManager.distanceKm
        let calories = sessionManager.activeCalories

        let record = ExerciseRecord(
            date: sessionManager.startDate ?? Date(),
            exerciseType: exercise.name,
            duration: elapsed,
            distance: distanceKm > 0.001 ? distanceKm : nil,
            exerciseDefinitionID: exercise.id,
            primaryMuscles: exercise.primaryMuscles,
            secondaryMuscles: exercise.secondaryMuscles,
            equipment: exercise.equipment,
            estimatedCalories: calories > 0 ? calories : nil,
            calorieSource: calories > 0 ? .healthKit : .met
        )

        // Create a single WorkoutSet representing the entire session
        let durationSeconds = elapsed
        let workoutSet = WorkoutSet(
            setNumber: 1,
            setType: .working,
            duration: durationSeconds,
            distance: distanceKm > 0.001 ? distanceKm : nil,
            isCompleted: true
        )
        workoutSet.exerciseRecord = record
        record.sets = [workoutSet]

        return record
    }

    /// Call from View after successfully inserting record into ModelContext.
    func didFinishSaving() {
        isSaving = false
    }

    /// Reset the session manager for reuse.
    func cleanup() {
        sessionManager.reset()
    }
}
