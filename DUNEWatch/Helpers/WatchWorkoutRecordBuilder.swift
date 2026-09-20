import Foundation

/// Keeps the saved workout and both WatchConnectivity delivery paths consistent.
@MainActor
enum WatchWorkoutRecordBuilder {
    static func makeRecord(
        exerciseName: String,
        exerciseDefinitionID: String,
        sets: [CompletedSetData],
        startDate: Date,
        duration: TimeInterval,
        calories: Double?,
        calorieSource: CalorieSource,
        effort: Int,
        healthKitWorkoutID: String?
    ) -> ExerciseRecord {
        let record = ExerciseRecord(
            date: startDate,
            exerciseType: exerciseName,
            duration: duration,
            calories: calorieSource == .healthKit ? calories : nil,
            healthKitWorkoutID: healthKitWorkoutID,
            exerciseDefinitionID: exerciseDefinitionID,
            estimatedCalories: calorieSource == .met ? calories : nil,
            calorieSource: calorieSource,
            rpe: effort
        )
        record.sets = sets.map { data in
            let set = WorkoutSet(
                setNumber: data.setNumber,
                setType: .working,
                weight: data.weight,
                reps: data.reps,
                duration: data.duration,
                isCompleted: true,
                restDuration: data.restDuration,
                rpe: data.rpe
            )
            set.exerciseRecord = record
            return set
        }
        // Set RPE remains available for analysis; the summary's chosen effort is final.
        return record
    }

    static func makeUpdate(from record: ExerciseRecord) -> WatchWorkoutUpdate {
        let sets = (record.sets ?? []).filter(\.isCompleted).sorted { $0.setNumber < $1.setNumber }
        return WatchWorkoutUpdate(
            exerciseID: record.exerciseDefinitionID ?? "",
            exerciseName: record.exerciseType,
            completedSets: sets.map { set in
                WatchSetData(
                    setNumber: set.setNumber,
                    weight: set.weight,
                    reps: set.reps,
                    duration: set.duration,
                    restDuration: set.restDuration,
                    isCompleted: true,
                    rpe: set.rpe
                )
            },
            startTime: record.date,
            endTime: record.date.addingTimeInterval(record.duration),
            heartRateSamples: [],
            rpe: record.rpe,
            healthKitWorkoutID: record.healthKitWorkoutID,
            calories: record.bestCalories,
            calorieSourceRaw: record.calorieSourceRaw
        )
    }
}
