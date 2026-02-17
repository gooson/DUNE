import Foundation

/// Muscle fatigue state computed from recent training history
struct MuscleFatigueState: Sendable {
    let muscle: MuscleGroup
    /// Days since last trained (nil if never trained)
    let daysSinceLastTrained: Int?
    /// Total sets targeting this muscle in the last 7 days
    let weeklyVolume: Int
    /// Recovery percentage (0.0 = just trained, 1.0 = fully recovered)
    let recoveryPercent: Double

    var isRecovered: Bool { recoveryPercent >= 0.8 }
    var isOverworked: Bool { weeklyVolume >= 20 }
}

/// A suggested workout with exercises and reasoning
struct WorkoutSuggestion: Sendable {
    let exercises: [SuggestedExercise]
    let reasoning: String
    let focusMuscles: [MuscleGroup]
}

struct SuggestedExercise: Identifiable, Sendable {
    let id: String
    let definition: ExerciseDefinition
    let suggestedSets: Int
    let reason: String
}

/// Protocol for workout recommendation
protocol WorkoutRecommending: Sendable {
    func recommend(
        from records: [ExerciseRecordSnapshot],
        library: ExerciseLibraryQuerying
    ) -> WorkoutSuggestion?
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
/// 1. Compute fatigue state for each muscle group based on recent records
/// 2. Rank muscles by recovery (prefer recovered, under-trained muscles)
/// 3. Select 3-5 exercises targeting the most recovered muscles
/// 4. Balance push/pull/legs for weekly variety
struct WorkoutRecommendationService: WorkoutRecommending {

    // Recovery model constants
    private let fullRecoveryHours: Double = 72  // 3 days for full recovery
    private let primaryFatigueMultiplier: Double = 1.0
    private let secondaryFatigueMultiplier: Double = 0.5
    private let maxWeeklyVolume = 20  // sets per muscle group
    private let targetExerciseCount = 4

    func recommend(
        from records: [ExerciseRecordSnapshot],
        library: ExerciseLibraryQuerying
    ) -> WorkoutSuggestion? {
        let fatigueStates = computeFatigueStates(from: records)

        // Find recovered, under-trained muscles
        let candidates = fatigueStates
            .filter { $0.isRecovered && !$0.isOverworked }
            .sorted { lhs, rhs in
                // Prioritize: most recovered + least weekly volume
                if lhs.recoveryPercent != rhs.recoveryPercent {
                    return lhs.recoveryPercent > rhs.recoveryPercent
                }
                return lhs.weeklyVolume < rhs.weeklyVolume
            }

        guard !candidates.isEmpty else {
            return WorkoutSuggestion(
                exercises: [],
                reasoning: "All muscle groups are still recovering. Consider a rest day or light cardio.",
                focusMuscles: []
            )
        }

        // Select top muscle groups (up to 3 for focus)
        let focusMuscles = Array(candidates.prefix(3).map(\.muscle))

        // Find exercises targeting these muscles
        var selectedExercises: [SuggestedExercise] = []
        var usedIDs = Set<String>()

        for muscle in focusMuscles {
            let exercises = library.exercises(forMuscle: muscle)
                .filter { $0.category == .strength || $0.category == .bodyweight }
                .filter { !usedIDs.contains($0.id) }

            // Pick the first matching exercise (could be randomized for variety)
            if let exercise = exercises.first {
                usedIDs.insert(exercise.id)
                let fatigueState = fatigueStates.first { $0.muscle == muscle }
                let suggestedSets = suggestedSetCount(for: fatigueState)

                selectedExercises.append(SuggestedExercise(
                    id: exercise.id,
                    definition: exercise,
                    suggestedSets: suggestedSets,
                    reason: reasonText(for: muscle, state: fatigueState)
                ))
            }

            if selectedExercises.count >= targetExerciseCount { break }
        }

        // If we still need more exercises, add compound movements
        if selectedExercises.count < targetExerciseCount {
            let compounds = library.allExercises()
                .filter { $0.primaryMuscles.count >= 2 || !$0.secondaryMuscles.isEmpty }
                .filter { $0.category == .strength }
                .filter { !usedIDs.contains($0.id) }
                .prefix(targetExerciseCount - selectedExercises.count)

            for exercise in compounds {
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
            // Find last training date for this muscle
            let muscleRecords = records.filter {
                $0.primaryMuscles.contains(muscle) || $0.secondaryMuscles.contains(muscle)
            }
            let lastTrainedDate = muscleRecords.map(\.date).max()

            // Compute days since last trained
            let daysSince: Int? = lastTrainedDate.map { date in
                max(0, Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0)
            }

            // Recovery percentage based on time since last trained
            let recovery: Double
            if let daysSince {
                let hoursSince = Double(daysSince) * 24.0
                recovery = min(hoursSince / fullRecoveryHours, 1.0)
            } else {
                recovery = 1.0  // Never trained = fully "recovered"
            }

            return MuscleFatigueState(
                muscle: muscle,
                daysSinceLastTrained: daysSince,
                weeklyVolume: volumeByMuscle[muscle] ?? 0,
                recoveryPercent: recovery
            )
        }
    }

    // MARK: - Helpers

    private func suggestedSetCount(for state: MuscleFatigueState?) -> Int {
        guard let state else { return 3 }
        let remaining = max(maxWeeklyVolume - state.weeklyVolume, 0)
        return min(max(remaining / 2, 2), 5)
    }

    private func reasonText(for muscle: MuscleGroup, state: MuscleFatigueState?) -> String {
        guard let state else { return "No recent data for \(muscle.rawValue)" }

        if let days = state.daysSinceLastTrained, days >= 3 {
            return "\(days) days since last trained, \(state.weeklyVolume) sets this week"
        } else if state.weeklyVolume < 10 {
            return "Low weekly volume (\(state.weeklyVolume) sets), room for more"
        } else {
            return "Recovered and ready for training"
        }
    }
}
