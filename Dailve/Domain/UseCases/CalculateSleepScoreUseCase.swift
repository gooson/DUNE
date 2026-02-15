import Foundation

protocol SleepScoreCalculating: Sendable {
    func execute(input: CalculateSleepScoreUseCase.Input) -> CalculateSleepScoreUseCase.Output
}

struct CalculateSleepScoreUseCase: SleepScoreCalculating, Sendable {
    // Score weights (total = 100)
    private let durationMaxScore = 40.0
    private let deepSleepMaxScore = 30.0
    private let efficiencyMaxScore = 30.0

    // Duration thresholds (hours)
    private let idealDurationRange = 7.0...9.0
    private let acceptableDurationRange = 6.0...10.0
    private let idealDurationCenter = 8.0
    private let durationPenaltyRate = 10.0

    // Deep sleep thresholds (ratio)
    private let idealDeepSleepRange = 0.15...0.25
    private let idealDeepSleepCenter = 0.20
    private let deepSleepPenaltyRate = 150.0

    struct Input: Sendable {
        let stages: [SleepStage]
    }

    struct Output: Sendable {
        let score: Int
        let totalMinutes: Double
        let efficiency: Double
    }

    func execute(input: Input) -> Output {
        let allDuration = input.stages.map(\.duration).reduce(0, +)
        let sleepDuration = input.stages
            .filter { $0.stage != .awake }
            .map(\.duration)
            .reduce(0, +)
        let totalMinutes = sleepDuration / 60.0

        let efficiency: Double
        if allDuration > 0 {
            efficiency = (sleepDuration / allDuration) * 100
        } else {
            efficiency = 0
        }

        guard totalMinutes > 0 else {
            return Output(score: 0, totalMinutes: 0, efficiency: 0)
        }

        let hours = totalMinutes / 60
        let durationScore: Double
        if idealDurationRange.contains(hours) {
            durationScore = durationMaxScore
        } else if acceptableDurationRange.contains(hours) {
            durationScore = durationMaxScore - durationPenaltyRate
        } else {
            durationScore = max(0, durationMaxScore - abs(hours - idealDurationCenter) * durationPenaltyRate)
        }

        let deepMinutes = input.stages
            .filter { $0.stage == .deep }
            .map(\.duration)
            .reduce(0, +) / 60.0
        let deepRatio = deepMinutes / totalMinutes
        let deepScore: Double
        if idealDeepSleepRange.contains(deepRatio) {
            deepScore = deepSleepMaxScore
        } else {
            deepScore = max(0, deepSleepMaxScore - abs(deepRatio - idealDeepSleepCenter) * deepSleepPenaltyRate)
        }

        let efficiencyScore = min(efficiencyMaxScore, efficiency / 100 * efficiencyMaxScore)

        let score = Int(min(100, durationScore + deepScore + efficiencyScore))
        return Output(score: score, totalMinutes: totalMinutes, efficiency: efficiency)
    }
}
