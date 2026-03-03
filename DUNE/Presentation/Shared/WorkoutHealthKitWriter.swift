import Foundation

/// Centralizes fire-and-forget HealthKit workout writes for exercise records.
/// Used by WorkoutSessionView, CompoundWorkoutView, and TemplateWorkoutView.
enum WorkoutHealthKitWriter {
    /// Writes an exercise record to HealthKit. Updates `record.healthKitWorkoutID` on success.
    @MainActor
    static func write(record: ExerciseRecord, exercise: ExerciseDefinition) {
        guard !record.isFromHealthKit else { return }

        let resolvedActivityType: WorkoutActivityType? = {
            guard exercise.inputType == .durationDistance else { return nil }
            return WorkoutActivityType.resolveDistanceBased(
                from: exercise.id,
                name: exercise.name,
                inputTypeRaw: exercise.inputType.rawValue
            ) ?? exercise.resolvedActivityType
        }()
        let totalDistanceKm: Double? = {
            if let distance = record.distance, distance > 0 { return distance }
            let setDistance = record.completedSets.compactMap(\.distance).reduce(0, +)
            return setDistance > 0 ? setDistance : nil
        }()
        let input = WorkoutWriteInput(
            startDate: record.date,
            duration: record.duration,
            category: exercise.category,
            exerciseName: record.exerciseType,
            estimatedCalories: record.estimatedCalories,
            isFromHealthKit: record.isFromHealthKit,
            distanceKm: totalDistanceKm,
            stepCount: record.stepCount,
            averagePaceSecondsPerKm: record.averagePaceSecondsPerKm,
            averageCadenceStepsPerMinute: record.averageCadenceStepsPerMinute,
            elevationGainMeters: record.elevationGainMeters,
            floorsAscended: record.floorsAscended,
            activityType: resolvedActivityType
        )
        Task {
            do {
                let hkID = try await WorkoutWriteService().saveWorkout(input)
                record.healthKitWorkoutID = hkID
            } catch {
                AppLogger.healthKit.error("Failed to write workout to HealthKit: \(error.localizedDescription)")
            }
        }
    }
}
