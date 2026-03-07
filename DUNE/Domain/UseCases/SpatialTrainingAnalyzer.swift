import Foundation

protocol SpatialTrainingAnalyzing: Sendable {
    func buildSummary(
        workouts: [WorkoutSummary],
        latestHeartRateBPM: Double?,
        baselineRHR: Double?,
        generatedAt: Date
    ) -> SpatialTrainingSummary
}

struct SpatialTrainingSummary: Sendable {
    struct HeartRateOrb: Sendable {
        let currentBPM: Double?
        let baselineRHR: Double?

        var displayBPM: Int? {
            guard let bpm = currentBPM ?? baselineRHR else { return nil }
            return Int(bpm.rounded())
        }

        var deltaFromBaseline: Int? {
            guard let currentBPM, let baselineRHR else { return nil }
            return Int((currentBPM - baselineRHR).rounded())
        }

        var normalizedPulse: Double {
            let fallbackBaseline = max(baselineRHR ?? 58, 35)
            let sourceBPM = currentBPM ?? baselineRHR ?? fallbackBaseline
            guard sourceBPM.isFinite else { return 0.2 }

            let ratio = ((sourceBPM - fallbackBaseline) / fallbackBaseline)
                .clamped(to: -0.3...1.4)
            return (0.22 + (ratio * 0.46)).clamped(to: 0.16...0.95)
        }

        var heatLevel: Double {
            let delta = Double(deltaFromBaseline ?? 0)
            return ((delta + 12) / 36).clamped(to: 0.12...1.0)
        }

        var isLive: Bool {
            currentBPM != nil
        }
    }

    struct MuscleLoad: Sendable, Identifiable {
        let muscle: MuscleGroup
        let weeklyLoadUnits: Int
        let fatigueLevel: FatigueLevel
        let recoveryPercent: Double
        let normalizedFatigue: Double
        let lastTrainedDate: Date?
        let nextReadyDate: Date?

        var id: MuscleGroup { muscle }

        var hasRecentLoad: Bool {
            weeklyLoadUnits > 0 || lastTrainedDate != nil
        }
    }

    let heartRateOrb: HeartRateOrb
    let muscleLoads: [MuscleLoad]
    let generatedAt: Date

    var featuredMuscles: [MuscleLoad] {
        muscleLoads
            .filter(\.hasRecentLoad)
            .sorted { lhs, rhs in
                if lhs.weeklyLoadUnits != rhs.weeklyLoadUnits {
                    return lhs.weeklyLoadUnits > rhs.weeklyLoadUnits
                }
                if lhs.normalizedFatigue != rhs.normalizedFatigue {
                    return lhs.normalizedFatigue > rhs.normalizedFatigue
                }
                return lhs.muscle.rawValue < rhs.muscle.rawValue
            }
            .prefix(6)
            .map { $0 }
    }

    var hasAnyData: Bool {
        heartRateOrb.currentBPM != nil
            || heartRateOrb.baselineRHR != nil
            || muscleLoads.contains(where: { $0.hasRecentLoad })
    }
}

struct SpatialTrainingAnalyzer: SpatialTrainingAnalyzing, Sendable {
    private let fatigueCalculator: FatigueCalculating

    init(fatigueCalculator: FatigueCalculating = FatigueCalculationService()) {
        self.fatigueCalculator = fatigueCalculator
    }

    func buildSummary(
        workouts: [WorkoutSummary],
        latestHeartRateBPM: Double?,
        baselineRHR: Double?,
        generatedAt: Date = Date()
    ) -> SpatialTrainingSummary {
        let snapshots = workouts.compactMap(Self.snapshot(from:))
        let fatigueStates = computeFatigueStates(from: snapshots, referenceDate: generatedAt)

        let muscleLoads = fatigueStates.map { state in
            SpatialTrainingSummary.MuscleLoad(
                muscle: state.muscle,
                weeklyLoadUnits: state.weeklyVolume,
                fatigueLevel: state.fatigueLevel,
                recoveryPercent: state.recoveryPercent,
                normalizedFatigue: normalizedFatigue(for: state),
                lastTrainedDate: state.lastTrainedDate,
                nextReadyDate: state.nextReadyDate
            )
        }

        return SpatialTrainingSummary(
            heartRateOrb: .init(currentBPM: latestHeartRateBPM, baselineRHR: baselineRHR),
            muscleLoads: muscleLoads,
            generatedAt: generatedAt
        )
    }

    static func snapshot(from workout: WorkoutSummary) -> ExerciseRecordSnapshot? {
        let mapping = resolveMuscles(for: workout)
        guard !mapping.primary.isEmpty || !mapping.secondary.isEmpty else {
            return nil
        }

        let durationMinutes = max(workout.duration / 60.0, 0)
        let distanceKm: Double? = workout.distance.map { meters in
            let km = meters / 1_000.0
            return km > 0 && km.isFinite ? km : nil
        } ?? nil

        return ExerciseRecordSnapshot(
            date: workout.date,
            exerciseName: workout.type,
            primaryMuscles: mapping.primary,
            secondaryMuscles: mapping.secondary,
            completedSetCount: pseudoLoadUnits(for: workout),
            durationMinutes: durationMinutes > 0 ? durationMinutes : nil,
            distanceKm: distanceKm
        )
    }

    static func pseudoLoadUnits(for workout: WorkoutSummary) -> Int {
        let durationMinutes = max(workout.duration / 60.0, 1)
        let distanceKm = max((workout.distance ?? 0) / 1_000.0, 0)

        let rawUnits: Double
        switch workout.activityType.category {
        case .strength:
            rawUnits = ceil(durationMinutes / 8.0)
        case .mindBody:
            rawUnits = ceil(durationMinutes / 20.0)
        case .cardio, .sports, .water, .winter, .outdoor, .dance, .combat, .multiSport:
            rawUnits = max(ceil(durationMinutes / 12.0), ceil(distanceKm))
        case .other:
            rawUnits = ceil(durationMinutes / 15.0)
        }

        return Int(rawUnits.clamped(to: 1...20))
    }

    private static func resolveMuscles(for workout: WorkoutSummary) -> (primary: [MuscleGroup], secondary: [MuscleGroup]) {
        let primary = workout.activityType.primaryMuscles
        let secondary = workout.activityType.secondaryMuscles

        guard primary.isEmpty else {
            return (primary, secondary)
        }

        if workout.activityType.category == .strength || workout.type.localizedCaseInsensitiveContains("strength") {
            switch workout.activityType {
            case .functionalStrengthTraining:
                return (
                    primary: [.quadriceps, .glutes, .core, .shoulders],
                    secondary: [.hamstrings, .back, .triceps]
                )
            default:
                return (
                    primary: [.chest, .back, .quadriceps, .shoulders],
                    secondary: [.biceps, .triceps, .core]
                )
            }
        }

        return ([], [])
    }

    private func computeFatigueStates(
        from records: [ExerciseRecordSnapshot],
        referenceDate: Date
    ) -> [MuscleFatigueState] {
        let volumeByMuscle = records.weeklyMuscleVolume(from: referenceDate)
        let compoundScores = fatigueCalculator.computeCompoundFatigue(
            for: Array(MuscleGroup.allCases),
            from: records,
            sleepModifier: 1.0,
            readinessModifier: 1.0,
            referenceDate: referenceDate
        )
        let scoreByMuscle = Dictionary(
            compoundScores.map { ($0.muscle, $0) },
            uniquingKeysWith: { _, latest in latest }
        )

        return MuscleGroup.allCases.map { muscle in
            let muscleRecords = records.filter {
                $0.primaryMuscles.contains(muscle) || $0.secondaryMuscles.contains(muscle)
            }
            let lastTrainedDate = muscleRecords.map(\.date).max()
            let hoursSinceLastTrained = lastTrainedDate.map { trainedDate in
                max(0, referenceDate.timeIntervalSince(trainedDate) / 3600.0)
            }

            let recoveryPercent: Double
            if let hoursSinceLastTrained, muscle.recoveryHours > 0 {
                recoveryPercent = min(hoursSinceLastTrained / muscle.recoveryHours, 1.0)
            } else {
                recoveryPercent = 1.0
            }

            return MuscleFatigueState(
                muscle: muscle,
                lastTrainedDate: lastTrainedDate,
                hoursSinceLastTrained: hoursSinceLastTrained,
                weeklyVolume: volumeByMuscle[muscle] ?? 0,
                recoveryPercent: recoveryPercent,
                compoundScore: scoreByMuscle[muscle]
            )
        }
    }

    private func normalizedFatigue(for state: MuscleFatigueState) -> Double {
        let raw = state.compoundScore?.normalizedScore ?? (1.0 - state.recoveryPercent)
        guard raw.isFinite else { return 0 }
        return raw.clamped(to: 0...1)
    }
}