import Foundation

/// Pure domain logic for detecting milestones and personal records.
/// No HealthKit or SwiftData dependencies.
enum PersonalRecordService {

    /// Checks which personal records the given workout beats compared to existing records.
    static func detectNewRecords(
        workout: WorkoutSummary,
        existingRecords: [PersonalRecordType: PersonalRecord]
    ) -> [PersonalRecordType] {
        var newRecords: [PersonalRecordType] = []

        // Fastest pace (only for distance-based activities with valid pace)
        if let pace = workout.averagePace, pace > 0, pace.isFinite, pace < 3600,
           workout.activityType.isDistanceBased {
            if let existing = existingRecords[.fastestPace] {
                if pace < existing.value { newRecords.append(.fastestPace) }
            } else {
                newRecords.append(.fastestPace)
            }
        }

        // Longest distance
        if let distance = workout.distance, distance > 0, distance.isFinite {
            if let existing = existingRecords[.longestDistance] {
                if distance > existing.value { newRecords.append(.longestDistance) }
            } else {
                newRecords.append(.longestDistance)
            }
        }

        // Highest calories
        if let calories = workout.calories, calories > 0, calories.isFinite, calories < 10_000 {
            if let existing = existingRecords[.highestCalories] {
                if calories > existing.value { newRecords.append(.highestCalories) }
            } else {
                newRecords.append(.highestCalories)
            }
        }

        // Longest duration
        let duration = workout.duration
        if duration > 0, duration.isFinite, duration < 86_400 {
            if let existing = existingRecords[.longestDuration] {
                if duration > existing.value { newRecords.append(.longestDuration) }
            } else {
                newRecords.append(.longestDuration)
            }
        }

        // Highest elevation (max ~9000m Everest; allow 10000 for safety)
        if let elevation = workout.elevationAscended, elevation > 0, elevation.isFinite, elevation < 10_000 {
            if let existing = existingRecords[.highestElevation] {
                if elevation > existing.value { newRecords.append(.highestElevation) }
            } else {
                newRecords.append(.highestElevation)
            }
        }

        return newRecords
    }

    /// Builds PersonalRecord entries from a workout for the given record types.
    static func buildRecords(
        from workout: WorkoutSummary,
        types: [PersonalRecordType]
    ) -> [PersonalRecordType: PersonalRecord] {
        var records: [PersonalRecordType: PersonalRecord] = [:]
        for type in types {
            guard let value = recordValue(for: type, from: workout) else { continue }
            records[type] = PersonalRecord(
                type: type, value: value,
                date: workout.date, workoutID: workout.id
            )
        }
        return records
    }

    private static func recordValue(for type: PersonalRecordType, from workout: WorkoutSummary) -> Double? {
        switch type {
        case .fastestPace: workout.averagePace
        case .longestDistance: workout.distance
        case .highestCalories: workout.calories
        case .longestDuration: workout.duration
        case .highestElevation: workout.elevationAscended
        }
    }
}

// MARK: - TrainingLoadService

/// Pure domain logic for calculating training load from workout data.
enum TrainingLoadService {

    /// Calculates daily training load for a single workout.
    /// Priority: effortScore > rpe > HR-based TRIMP.
    static func calculateLoad(
        effortScore: Double?,
        rpe: Int?,
        durationMinutes: Double,
        heartRateAvg: Double?,
        restingHR: Double?,
        maxHR: Double?
    ) -> TrainingLoad.LoadSource? {
        // Guard: duration must be positive
        guard durationMinutes > 0, durationMinutes.isFinite else { return nil }

        if let effort = effortScore, effort > 0, effort <= 10 {
            return .effort
        }
        if let rpe, rpe >= 1, rpe <= 10 {
            return .rpe
        }
        if heartRateAvg != nil, restingHR != nil, maxHR != nil {
            return .trimp
        }
        return nil
    }

    /// Computes the numeric load value.
    static func computeLoadValue(
        source: TrainingLoad.LoadSource,
        effortScore: Double?,
        rpe: Int?,
        durationMinutes: Double,
        heartRateAvg: Double?,
        restingHR: Double?,
        maxHR: Double?
    ) -> Double {
        switch source {
        case .effort:
            let effort = effortScore ?? 5.0
            let result = effort * durationMinutes / 60.0
            guard result.isFinite, !result.isNaN else { return 0 }
            return result

        case .rpe:
            let rpeValue = Double(rpe ?? 5)
            let result = rpeValue * durationMinutes / 60.0
            guard result.isFinite, !result.isNaN else { return 0 }
            return result

        case .trimp:
            guard let avgHR = heartRateAvg, let restHR = restingHR, let mHR = maxHR,
                  mHR > restHR, avgHR >= restHR, avgHR <= mHR else {
                return 0
            }
            let hrRatio = (avgHR - restHR) / (mHR - restHR)
            let result = durationMinutes * hrRatio * hrRatio
            guard result.isFinite, !result.isNaN else { return 0 }
            return result
        }
    }
}
