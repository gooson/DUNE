import Foundation

/// Protocol for workout recommendation
protocol WorkoutRecommending: Sendable {
    func recommend(
        from records: [ExerciseRecordSnapshot],
        library: ExerciseLibraryQuerying
    ) -> WorkoutSuggestion?

    func computeFatigueStates(from records: [ExerciseRecordSnapshot]) -> [MuscleFatigueState]
}

/// Lightweight snapshot of ExerciseRecord for recommendation (avoids SwiftData dependency)
struct ExerciseRecordSnapshot: Sendable {
    let date: Date
    let exerciseDefinitionID: String?
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let completedSetCount: Int
}

extension ExerciseRecordSnapshot: ExerciseRecordVolumeProviding {
    var volumeDate: Date { date }
    var volumeSetCount: Int { completedSetCount }
    var volumePrimaryMuscles: [MuscleGroup] { primaryMuscles }
    var volumeSecondaryMuscles: [MuscleGroup] { secondaryMuscles }
}

/// Recovery-based workout recommendation engine
///
/// Algorithm:
/// 1. Compute fatigue state for each muscle group based on recent records (hour-based, differential recovery)
/// 2. Rank muscles by recovery (prefer recovered, under-trained muscles) + weekday pattern bonus
/// 3. Select 3-5 exercises targeting the most recovered muscles (prefer least-recently performed)
/// 4. Fill remaining slots with compound movements (recovery-verified)
struct WorkoutRecommendationService: WorkoutRecommending {

    private let maxWeeklyVolume = 20  // sets per muscle group
    private let targetExerciseCount = 4
    private let maxAlternatives = 3
    private let weekdayPatternMinWeeks = 4  // Minimum weeks of data before applying weekday bonus

    func recommend(
        from records: [ExerciseRecordSnapshot],
        library: ExerciseLibraryQuerying
    ) -> WorkoutSuggestion? {
        let fatigueStates = computeFatigueStates(from: records)
        let weekdayBonusMuscles = computeWeekdayPatterns(from: records)

        // Find recovered, under-trained muscles
        let candidates = fatigueStates
            .filter { $0.isRecovered && !$0.isOverworked }
            .sorted { lhs, rhs in
                let lhsBonus: Double = weekdayBonusMuscles.contains(lhs.muscle) ? 0.1 : 0.0
                let rhsBonus: Double = weekdayBonusMuscles.contains(rhs.muscle) ? 0.1 : 0.0
                let lhsScore = lhs.recoveryPercent + lhsBonus
                let rhsScore = rhs.recoveryPercent + rhsBonus
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.weeklyVolume < rhs.weeklyVolume
            }

        guard !candidates.isEmpty else {
            return restDaySuggestion(from: fatigueStates)
        }

        // Select top muscle groups (up to 3 for focus)
        let focusMuscles = Array(candidates.prefix(3).map(\.muscle))

        // Find exercises targeting these muscles
        var selectedExercises: [SuggestedExercise] = []
        var usedIDs = Set<String>()

        for muscle in focusMuscles {
            let allForMuscle = library.exercises(forMuscle: muscle)
                .filter { $0.category == .strength || $0.category == .bodyweight }
                .filter { !usedIDs.contains($0.id) }

            // Prefer least-recently performed exercise for variety
            let sorted = sortByLeastRecent(exercises: allForMuscle, records: records)

            if let exercise = sorted.first {
                usedIDs.insert(exercise.id)
                let fatigueState = fatigueStates.first { $0.muscle == muscle }
                let suggestedSets = suggestedSetCount(for: fatigueState)
                let alternatives = Array(sorted.dropFirst().prefix(maxAlternatives))

                selectedExercises.append(SuggestedExercise(
                    id: exercise.id,
                    definition: exercise,
                    suggestedSets: suggestedSets,
                    reason: reasonText(for: muscle, state: fatigueState),
                    alternatives: alternatives
                ))
            }

            if selectedExercises.count >= targetExerciseCount { break }
        }

        // Fill remaining slots with compound movements — recovery-verified
        if selectedExercises.count < targetExerciseCount {
            let fatigueByMuscle = Dictionary(
                uniqueKeysWithValues: fatigueStates.map { ($0.muscle, $0) }
            )

            let compounds = library.allExercises()
                .filter { $0.primaryMuscles.count >= 2 || !$0.secondaryMuscles.isEmpty }
                .filter { $0.category == .strength }
                .filter { !usedIDs.contains($0.id) }
                .filter { exercise in
                    // All primary muscles must be recovered
                    exercise.primaryMuscles.allSatisfy { muscle in
                        fatigueByMuscle[muscle]?.isRecovered == true
                    }
                }

            let sortedCompounds = sortByLeastRecent(exercises: Array(compounds), records: records)

            for exercise in sortedCompounds.prefix(targetExerciseCount - selectedExercises.count) {
                usedIDs.insert(exercise.id)
                selectedExercises.append(SuggestedExercise(
                    id: exercise.id,
                    definition: exercise,
                    suggestedSets: 3,
                    reason: "Compound movement for overall development"
                ))
            }
        }

        guard !selectedExercises.isEmpty else { return nil }

        let muscleNames = focusMuscles.map(\.rawValue).joined(separator: ", ")
        let reasoning = "Focus on \(muscleNames) — these muscles are well-recovered and could use more volume this week."

        return WorkoutSuggestion(
            exercises: selectedExercises,
            reasoning: reasoning,
            focusMuscles: focusMuscles
        )
    }

    // MARK: - Fatigue Computation

    func computeFatigueStates(from records: [ExerciseRecordSnapshot]) -> [MuscleFatigueState] {
        let now = Date()
        let volumeByMuscle = records.weeklyMuscleVolume(from: now)

        return MuscleGroup.allCases.map { muscle in
            let muscleRecords = records.filter {
                $0.primaryMuscles.contains(muscle) || $0.secondaryMuscles.contains(muscle)
            }
            let lastTrainedDate = muscleRecords.map(\.date).max()

            // Hour-based recovery using actual time interval
            let hoursSince: Double? = lastTrainedDate.map { date in
                max(0, now.timeIntervalSince(date) / 3600.0)
            }

            let recovery: Double
            if let hoursSince, muscle.recoveryHours > 0 {
                recovery = min(hoursSince / muscle.recoveryHours, 1.0)
            } else {
                recovery = 1.0  // Never trained or zero recoveryHours = fully "recovered"
            }

            return MuscleFatigueState(
                muscle: muscle,
                lastTrainedDate: lastTrainedDate,
                hoursSinceLastTrained: hoursSince,
                weeklyVolume: volumeByMuscle[muscle] ?? 0,
                recoveryPercent: recovery
            )
        }
    }

    // MARK: - Weekday Pattern

    /// Returns muscle groups that the user frequently trains on the current weekday.
    func computeWeekdayPatterns(from records: [ExerciseRecordSnapshot]) -> Set<MuscleGroup> {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: Date())

        // Only consider records from recent 8 weeks
        let eightWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -8, to: Date()) ?? Date()
        let relevantRecords = records.filter { $0.date >= eightWeeksAgo }

        // Need at least 4 weeks of data for meaningful patterns
        let distinctWeeks = Set(relevantRecords.compactMap { record -> Int? in
            calendar.component(.weekOfYear, from: record.date)
        })
        guard distinctWeeks.count >= weekdayPatternMinWeeks else { return [] }

        // Count muscle occurrences on this weekday
        let weekdayRecords = relevantRecords.filter {
            calendar.component(.weekday, from: $0.date) == currentWeekday
        }

        var muscleCounts: [MuscleGroup: Int] = [:]
        for record in weekdayRecords {
            for muscle in record.primaryMuscles {
                muscleCounts[muscle, default: 0] += 1
            }
        }

        // Return muscles trained on this weekday at least 3 times (out of ~8 weeks)
        return Set(muscleCounts.filter { $0.value >= 3 }.map(\.key))
    }

    // MARK: - Helpers

    private func suggestedSetCount(for state: MuscleFatigueState?) -> Int {
        guard let state else { return 3 }
        let remaining = max(maxWeeklyVolume - state.weeklyVolume, 0)
        return min(max(remaining / 2, 2), 5)
    }

    private func reasonText(for muscle: MuscleGroup, state: MuscleFatigueState?) -> String {
        guard let state else { return "No recent data for \(muscle.rawValue)" }

        if let hours = state.hoursSinceLastTrained {
            let days = Int(hours / 24)
            if days >= 3 {
                return "\(days) days since last trained, \(state.weeklyVolume) sets this week"
            }
        }
        if state.weeklyVolume < 10 {
            return "Low weekly volume (\(state.weeklyVolume) sets), room for more"
        }
        return "Recovered and ready for training"
    }

    private func restDaySuggestion(from fatigueStates: [MuscleFatigueState]) -> WorkoutSuggestion {
        // Find the muscle that will recover soonest
        let nextReady = fatigueStates
            .compactMap { state -> (muscle: MuscleGroup, readyDate: Date)? in
                guard let readyDate = state.nextReadyDate else { return nil }
                return (state.muscle, readyDate)
            }
            .min { $0.readyDate < $1.readyDate }

        return WorkoutSuggestion(
            exercises: [],
            reasoning: "Recovery in progress — your muscles are rebuilding stronger.",
            focusMuscles: [],
            activeRecoverySuggestions: ActiveRecoverySuggestion.defaults,
            nextReadyMuscle: nextReady
        )
    }

    /// Sort exercises by least-recently performed (never performed first, then oldest first)
    private func sortByLeastRecent(
        exercises: [ExerciseDefinition],
        records: [ExerciseRecordSnapshot]
    ) -> [ExerciseDefinition] {
        let lastPerformedByID: [String: Date] = {
            var result: [String: Date] = [:]
            for record in records {
                guard let defID = record.exerciseDefinitionID else { continue }
                if let existing = result[defID] {
                    if record.date > existing { result[defID] = record.date }
                } else {
                    result[defID] = record.date
                }
            }
            return result
        }()

        return exercises.sorted { lhs, rhs in
            let lhsDate = lastPerformedByID[lhs.id] ?? .distantPast
            let rhsDate = lastPerformedByID[rhs.id] ?? .distantPast
            return lhsDate < rhsDate
        }
    }
}
