import Foundation

/// Builds a unified personal record list for Activity screens.
/// Keeps policy decisions centralized: HealthKit-first cardio, manual fallback.
enum ActivityPersonalRecordService: Sendable {

    struct ManualCardioEntry: Sendable {
        let title: String
        let date: Date
        let duration: TimeInterval
        let distanceMeters: Double?
        let calories: Double?
    }

    static func merge(
        strengthRecords: [StrengthPersonalRecord],
        cardioRecordsByActivity: [WorkoutActivityType: [PersonalRecordType: PersonalRecord]],
        manualCardioEntries: [ManualCardioEntry],
        referenceDate: Date = Date()
    ) -> [ActivityPersonalRecord] {
        var result: [ActivityPersonalRecord] = []

        // Strength PRs
        for record in strengthRecords where isValid(record.maxWeight, for: .strengthWeight) {
            result.append(
                ActivityPersonalRecord(
                    id: "strength-\(record.id)",
                    kind: .strengthWeight,
                    title: record.exerciseName,
                    subtitle: "Strength",
                    value: record.maxWeight,
                    date: record.date,
                    isRecent: record.isRecent,
                    source: .manual
                )
            )
        }

        // Cardio PRs from HealthKit-backed store
        var healthKitCardioKinds = Set<ActivityPersonalRecord.Kind>()
        for (activityType, recordsByType) in cardioRecordsByActivity {
            guard activityType.isDistanceBased || activityType.category == .cardio else { continue }
            for (recordType, record) in recordsByType {
                guard let kind = ActivityPersonalRecord.Kind(personalRecordType: recordType) else { continue }
                guard isValid(record.value, for: kind) else { continue }

                healthKitCardioKinds.insert(kind)
                result.append(
                    ActivityPersonalRecord(
                        id: "hk-\(activityType.rawValue)-\(kind.rawValue)",
                        kind: kind,
                        title: activityType.typeName,
                        subtitle: recordType.rawValue,
                        value: record.value,
                        date: record.date,
                        isRecent: isRecent(record.date, referenceDate: referenceDate),
                        source: .healthKit,
                        workoutID: record.workoutID,
                        heartRateAvg: record.heartRateAvg,
                        heartRateMax: record.heartRateMax,
                        heartRateMin: record.heartRateMin,
                        stepCount: record.stepCount,
                        weatherTemperature: record.weatherTemperature,
                        weatherCondition: record.weatherCondition,
                        weatherHumidity: record.weatherHumidity,
                        isIndoor: record.isIndoor
                    )
                )
            }
        }

        // Manual fallback only for cardio kinds missing from HealthKit records
        let manualFallback = manualFallbackRecords(
            from: manualCardioEntries,
            skippingKinds: healthKitCardioKinds,
            referenceDate: referenceDate
        )
        result.append(contentsOf: manualFallback)

        return result.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if lhs.kind.sortOrder != rhs.kind.sortOrder { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            return lhs.value > rhs.value
        }
    }

    // MARK: - Private

    private struct ManualMetricCandidate {
        let kind: ActivityPersonalRecord.Kind
        let title: String
        let value: Double
        let date: Date
    }

    private static func manualFallbackRecords(
        from entries: [ManualCardioEntry],
        skippingKinds: Set<ActivityPersonalRecord.Kind>,
        referenceDate: Date
    ) -> [ActivityPersonalRecord] {
        guard !entries.isEmpty else { return [] }

        var bestByKind: [ActivityPersonalRecord.Kind: ManualMetricCandidate] = [:]

        for entry in entries {
            // Longest duration
            if isValid(entry.duration, for: .longestDuration) {
                let candidate = ManualMetricCandidate(
                    kind: .longestDuration,
                    title: entry.title,
                    value: entry.duration,
                    date: entry.date
                )
                updateBest(candidate, in: &bestByKind)
            }

            // Highest calories
            if let calories = entry.calories, isValid(calories, for: .highestCalories) {
                let candidate = ManualMetricCandidate(
                    kind: .highestCalories,
                    title: entry.title,
                    value: calories,
                    date: entry.date
                )
                updateBest(candidate, in: &bestByKind)
            }

            guard let distance = entry.distanceMeters, isValid(distance, for: .longestDistance) else {
                continue
            }

            // Longest distance
            updateBest(
                ManualMetricCandidate(
                    kind: .longestDistance,
                    title: entry.title,
                    value: distance,
                    date: entry.date
                ),
                in: &bestByKind
            )

            // Fastest pace (sec/km)
            guard entry.duration > 0 else { continue }
            let distanceKm = distance / 1000.0
            guard distanceKm > 0 else { continue }
            let pace = entry.duration / distanceKm
            guard isValid(pace, for: .fastestPace) else { continue }
            updateBest(
                ManualMetricCandidate(
                    kind: .fastestPace,
                    title: entry.title,
                    value: pace,
                    date: entry.date
                ),
                in: &bestByKind
            )
        }

        return bestByKind.values
            .filter { !skippingKinds.contains($0.kind) }
            .map { candidate in
                ActivityPersonalRecord(
                    id: "manual-\(candidate.kind.rawValue)",
                    kind: candidate.kind,
                    title: candidate.title,
                    subtitle: "Manual Cardio",
                    value: candidate.value,
                    date: candidate.date,
                    isRecent: isRecent(candidate.date, referenceDate: referenceDate),
                    source: .manual
                )
            }
    }

    private static func updateBest(
        _ candidate: ManualMetricCandidate,
        in storage: inout [ActivityPersonalRecord.Kind: ManualMetricCandidate]
    ) {
        if let existing = storage[candidate.kind] {
            let shouldReplace: Bool
            if candidate.kind.isLowerBetter {
                shouldReplace = candidate.value < existing.value
            } else {
                shouldReplace = candidate.value > existing.value
            }
            if shouldReplace {
                storage[candidate.kind] = candidate
            }
        } else {
            storage[candidate.kind] = candidate
        }
    }

    private static func isRecent(_ date: Date, referenceDate: Date) -> Bool {
        let calendar = Calendar.current
        let daysDiff = calendar.dateComponents([.day], from: date, to: referenceDate).day ?? 0
        return daysDiff >= 0 && daysDiff <= 7
    }

    private static func isValid(_ value: Double, for kind: ActivityPersonalRecord.Kind) -> Bool {
        guard value > 0, value.isFinite else { return false }

        switch kind {
        case .strengthWeight:
            return value <= 500
        case .fastestPace:
            return value <= 3600
        case .longestDistance:
            return value <= 500_000
        case .highestCalories:
            return value <= 10_000
        case .longestDuration:
            return value <= 86_400
        case .highestElevation:
            return value <= 10_000
        }
    }
}
