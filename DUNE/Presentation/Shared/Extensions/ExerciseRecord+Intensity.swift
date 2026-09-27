import Foundation

extension ExerciseRecord {
    /// Recompute after effort changes, excluding the current record even after insertion.
    @discardableResult
    func refreshAutoIntensity(
        exerciseType: ExerciseInputType,
        history records: [ExerciseRecord],
        using service: WorkoutIntensityService = WorkoutIntensityService()
    ) -> WorkoutIntensityResult? {
        let cutoff = date.addingTimeInterval(-30 * 24 * 60 * 60)
        let history = records
            .filter {
                $0.id != id && $0.exerciseDefinitionID == exerciseDefinitionID
                    && $0.date >= cutoff && $0.date < date
            }
            .sorted { $0.date < $1.date }
            .map { $0.intensityInput(exerciseType: exerciseType) }
        let estimated1RM: Double?
        if exerciseType == .setsRepsWeight {
            let sessions = history.map { session in
                OneRMSessionInput(
                    date: session.date,
                    sets: session.sets.filter { $0.setType != .warmup }.map {
                        OneRMSetInput(weight: $0.weight, reps: $0.reps)
                    }
                )
            }
            estimated1RM = OneRMEstimationService().analyze(sessions: sessions).currentBest
        } else {
            estimated1RM = nil
        }
        let result = service.calculateIntensity(
            current: intensityInput(exerciseType: exerciseType), history: history, estimated1RM: estimated1RM
        )
        autoIntensityRaw = result?.rawScore
        return result
    }

    private func intensityInput(exerciseType: ExerciseInputType) -> IntensitySessionInput {
        IntensitySessionInput(
            date: date,
            exerciseType: exerciseType,
            sets: completedSets.map {
                IntensitySetInput(weight: $0.weight, reps: $0.reps, duration: $0.duration,
                                  distance: $0.distance, manualIntensity: $0.intensity, setType: $0.setType)
            },
            rpe: rpe
        )
    }
}
