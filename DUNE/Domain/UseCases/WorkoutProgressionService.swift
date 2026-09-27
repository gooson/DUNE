import Foundation

/// Planned and performed values stay separate; missing provenance is not a user rating.
struct ProgressionSetInput: Sendable {
    let weight: Double?
    let reps: Int?
    let plannedReps: Int?
    let rpe: Double?
    let rpeSourceRaw: String?
    let setType: SetType
    let isCompleted: Bool
}

struct WeightRecommendation: Sendable, Equatable {
    enum Reason: Sendable {
        case maintain
        case insufficientData
        case highEffort
        case missedTarget
        case readyToProgress
    }

    let weight: Double
    let reason: Reason
}

/// Conservative product policy, shared by iPhone and Watch. All weights are kilograms.
struct WorkoutProgressionService: Sendable {
    static func incrementKg(equipment: Equipment, primaryMuscles: [MuscleGroup]) -> Double {
        let lower: Set<MuscleGroup> = [.quadriceps, .hamstrings, .glutes]
        if !Set(primaryMuscles).intersection(lower).isEmpty { return 5 }
        switch equipment {
        case .dumbbell, .kettlebell, .band, .trx, .medicineBall, .stabilityBall, .bodyweight, .other:
            return 1
        default:
            return 2.5
        }
    }

    /// Within a session, completing a target never triggers another automatic increase.
    func nextSet(after set: ProgressionSetInput, incrementKg: Double) -> WeightRecommendation? {
        guard let weight = validWeight(set.weight), validIncrement(incrementKg),
              set.isCompleted, set.setType == .working else { return nil }
        let missed = validReps(set.plannedReps).flatMap { target in
            validReps(set.reps).map { $0 < target }
        } ?? false
        let high = userRPE(set).map { $0 >= 9 } ?? false
        if high || missed {
            let step = plateStep(incrementKg)
            // Round upward so a reduction never exceeds 10%, including light weights.
            let reduced = ceil(weight * 0.9 / step) * step
            return WeightRecommendation(
                weight: Swift.min(weight, reduced),
                reason: high ? .highEffort : .missedTarget
            )
        }
        return WeightRecommendation(
            weight: weight,
            reason: userRPE(set) == nil || validReps(set.plannedReps) == nil ? .insufficientData : .maintain
        )
    }

    /// Only a fully completed plan with confirmed, manageable effort qualifies.
    func nextSession(
        sets: [ProgressionSetInput],
        plannedSetCount: Int?,
        incrementKg: Double
    ) -> WeightRecommendation? {
        let working = sets.filter { $0.setType == .working }
        guard let first = working.first, let weight = validWeight(first.weight),
              validIncrement(incrementKg) else { return nil }
        let unchanged = WeightRecommendation(weight: weight, reason: .insufficientData)
        guard let plannedSetCount, plannedSetCount > 0,
              sets.count == plannedSetCount, sets.allSatisfy(\.isCompleted),
              !sets.contains(where: { $0.setType == .failure || $0.setType == .drop }) else { return unchanged }

        for set in working {
            guard validWeight(set.weight) != nil,
                  let target = validReps(set.plannedReps), let actual = validReps(set.reps),
                  let rpe = userRPE(set) else { return unchanged }
            if actual < target { return WeightRecommendation(weight: weight, reason: .missedTarget) }
            if rpe > 8 { return WeightRecommendation(weight: weight, reason: .highEffort) }
        }

        let maximum = Swift.min(500, weight + Swift.min(incrementKg, weight * 0.1))
        let increased = floor((maximum + 1e-9) / plateStep(incrementKg)) * plateStep(incrementKg)
        guard increased > weight, increased <= weight * 1.1 + 1e-9 else {
            return WeightRecommendation(weight: weight, reason: .maintain)
        }
        return WeightRecommendation(weight: increased, reason: .readyToProgress)
    }

    private func userRPE(_ set: ProgressionSetInput) -> Double? {
        guard set.rpeSourceRaw == "user", let rpe = set.rpe else { return nil }
        return RPELevel.validate(rpe)
    }

    private func validWeight(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0.01...500).contains(value) else { return nil }
        return value
    }

    private func validReps(_ value: Int?) -> Int? {
        guard let value, (1...1000).contains(value) else { return nil }
        return value
    }

    private func validIncrement(_ value: Double) -> Bool {
        value.isFinite && value > 0 && value <= 5
    }

    private func plateStep(_ increment: Double) -> Double { increment <= 1 ? 1 : 2.5 }
}
