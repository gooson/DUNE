import Foundation

protocol InjuryRiskCalculating: Sendable {
    func execute(input: CalculateInjuryRiskUseCase.Input) -> InjuryRiskAssessment
}

/// Calculates injury risk score (0-100) from fatigue, training patterns, sleep, and injury history.
///
/// Weights: muscleFatigue(25%) + consecutiveTraining(20%) + volumeSpike(20%)
///        + sleepDeficit(15%) + activeInjury(10%) + lowRecovery(10%)
struct CalculateInjuryRiskUseCase: InjuryRiskCalculating, Sendable {

    struct Input: Sendable {
        let fatigueStates: [MuscleFatigueState]
        let consecutiveTrainingDays: Int
        let currentWeekVolume: Double
        let previousWeekVolume: Double
        let sleepDeficitMinutes: Double
        let activeInjuries: [InjuryInfo]
        let conditionScore: Int?
    }

    // MARK: - Weights (total = 1.0)

    private let muscleFatigueWeight = 0.25
    private let consecutiveTrainingWeight = 0.20
    private let volumeSpikeWeight = 0.20
    private let sleepDeficitWeight = 0.15
    private let activeInjuryWeight = 0.10
    private let lowRecoveryWeight = 0.10

    // MARK: - Thresholds

    /// Number of consecutive training days that starts increasing risk.
    private let consecutiveDaysThreshold = 3
    /// Maximum consecutive days for full risk score.
    private let consecutiveDaysMax = 7
    /// Volume increase ratio that signals a spike (ACWR > 1.5).
    private let volumeSpikeRatio = 1.5
    /// Maximum volume ratio for full risk score.
    private let volumeSpikeMax = 2.5
    /// Sleep deficit in minutes that starts increasing risk (1 hour).
    private let sleepDeficitThreshold = 60.0
    /// Sleep deficit for full risk score (3 hours).
    private let sleepDeficitMax = 180.0

    func execute(input: Input) -> InjuryRiskAssessment {
        var factors: [InjuryRiskAssessment.RiskFactor] = []

        let fatigueRisk = computeMuscleFatigueRisk(input.fatigueStates)
        let consecutiveRisk = computeConsecutiveTrainingRisk(input.consecutiveTrainingDays)
        let volumeRisk = computeVolumeSpikeRisk(
            current: input.currentWeekVolume,
            previous: input.previousWeekVolume
        )
        let sleepRisk = computeSleepDeficitRisk(input.sleepDeficitMinutes)
        let injuryRisk = computeActiveInjuryRisk(input.activeInjuries)
        let recoveryRisk = computeLowRecoveryRisk(input.conditionScore)

        // Build factors list (only include meaningful contributions)
        if fatigueRisk > 0 {
            factors.append(.init(
                type: .muscleFatigue,
                contribution: Int(fatigueRisk * muscleFatigueWeight * 100),
                detail: formatFatigueDetail(input.fatigueStates)
            ))
        }
        if consecutiveRisk > 0 {
            factors.append(.init(
                type: .consecutiveTraining,
                contribution: Int(consecutiveRisk * consecutiveTrainingWeight * 100),
                detail: String(localized: "\(input.consecutiveTrainingDays) consecutive training days")
            ))
        }
        if volumeRisk > 0 {
            let ratio = input.previousWeekVolume > 0
                ? input.currentWeekVolume / input.previousWeekVolume
                : 0
            factors.append(.init(
                type: .volumeSpike,
                contribution: Int(volumeRisk * volumeSpikeWeight * 100),
                detail: String(localized: "Volume increased \(Int(ratio * 100))% vs last week")
            ))
        }
        if sleepRisk > 0 {
            let hours = input.sleepDeficitMinutes / 60.0
            let hoursFormatted = hours.formatted(.number.precision(.fractionLength(1)))
            factors.append(.init(
                type: .sleepDeficit,
                contribution: Int(sleepRisk * sleepDeficitWeight * 100),
                detail: String(localized: "\(hoursFormatted)h sleep deficit")
            ))
        }
        if injuryRisk > 0 {
            factors.append(.init(
                type: .activeInjury,
                contribution: Int(injuryRisk * activeInjuryWeight * 100),
                detail: String(localized: "\(input.activeInjuries.count) active injury")
            ))
        }
        if recoveryRisk > 0 {
            factors.append(.init(
                type: .lowRecovery,
                contribution: Int(recoveryRisk * lowRecoveryWeight * 100),
                detail: String(localized: "Low recovery score")
            ))
        }

        let rawScore = fatigueRisk * muscleFatigueWeight
            + consecutiveRisk * consecutiveTrainingWeight
            + volumeRisk * volumeSpikeWeight
            + sleepRisk * sleepDeficitWeight
            + injuryRisk * activeInjuryWeight
            + recoveryRisk * lowRecoveryWeight

        let score = Int(rawScore * 100)
        let sortedFactors = factors.sorted { $0.contribution > $1.contribution }
        return InjuryRiskAssessment(score: score, factors: sortedFactors)
    }

    // MARK: - Component Calculations

    /// Returns 0.0-1.0 based on proportion of overworked muscles.
    private func computeMuscleFatigueRisk(_ states: [MuscleFatigueState]) -> Double {
        guard !states.isEmpty else { return 0 }
        let overworkedCount = states.filter(\.isOverworked).count
        let highFatigueCount = states.filter { $0.fatigueLevel.rawValue >= 7 }.count
        let ratio = Double(overworkedCount + highFatigueCount) / Double(states.count * 2)
        return min(1.0, ratio)
    }

    /// Returns 0.0-1.0 based on consecutive training days.
    private func computeConsecutiveTrainingRisk(_ days: Int) -> Double {
        guard days > consecutiveDaysThreshold else { return 0 }
        let excess = Double(days - consecutiveDaysThreshold)
        let range = Double(consecutiveDaysMax - consecutiveDaysThreshold)
        guard range > 0 else { return 1.0 }
        return min(1.0, excess / range)
    }

    /// Returns 0.0-1.0 based on acute:chronic workload ratio.
    private func computeVolumeSpikeRisk(current: Double, previous: Double) -> Double {
        guard previous > 0, current > 0 else { return 0 }
        let ratio = current / previous
        guard ratio > volumeSpikeRatio else { return 0 }
        let excess = ratio - volumeSpikeRatio
        let range = volumeSpikeMax - volumeSpikeRatio
        guard range > 0 else { return 1.0 }
        return min(1.0, excess / range)
    }

    /// Returns 0.0-1.0 based on accumulated sleep deficit.
    private func computeSleepDeficitRisk(_ deficitMinutes: Double) -> Double {
        guard deficitMinutes > sleepDeficitThreshold else { return 0 }
        let excess = deficitMinutes - sleepDeficitThreshold
        let range = sleepDeficitMax - sleepDeficitThreshold
        guard range > 0 else { return 1.0 }
        return min(1.0, excess / range)
    }

    /// Returns 0.0-1.0 based on active injuries and their severity.
    private func computeActiveInjuryRisk(_ injuries: [InjuryInfo]) -> Double {
        let active = injuries.filter(\.isActive)
        guard !active.isEmpty else { return 0 }
        let maxSeverity = active.map(\.severity.riskWeight).max() ?? 0
        return min(1.0, maxSeverity)
    }

    /// Returns 0.0-1.0 based on condition score (low = high risk).
    private func computeLowRecoveryRisk(_ conditionScore: Int?) -> Double {
        guard let score = conditionScore else { return 0 }
        // Below 40 starts contributing to risk, below 20 = full risk
        guard score < 40 else { return 0 }
        return min(1.0, Double(40 - score) / 20.0)
    }

    // MARK: - Formatting Helpers

    private func formatFatigueDetail(_ states: [MuscleFatigueState]) -> String {
        let overworked = states.filter(\.isOverworked)
        if overworked.isEmpty {
            let high = states.filter { $0.fatigueLevel.rawValue >= 7 }
            if high.isEmpty {
                return String(localized: "Muscle fatigue detected")
            }
            return String(localized: "\(high.count) muscle groups with high fatigue")
        }
        return String(localized: "\(overworked.count) overworked muscle groups")
    }
}
