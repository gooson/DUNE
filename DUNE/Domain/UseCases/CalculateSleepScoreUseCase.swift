import Foundation

protocol SleepScoreCalculating: Sendable {
    func execute(input: CalculateSleepScoreUseCase.Input) -> CalculateSleepScoreUseCase.Output
}

struct CalculateSleepScoreUseCase: SleepScoreCalculating, Sendable {
    // Score weights (total = 100)
    private let durationMaxScore = 30.0
    private let deepSleepMaxScore = 20.0
    private let remSleepMaxScore = 15.0
    private let efficiencyMaxScore = 20.0
    private let wasoMaxScore = 15.0

    // Duration thresholds (hours)
    private let idealDurationRange = 7.0...9.0
    private let acceptableDurationRange = 6.0...10.0
    private let idealDurationCenter = 8.0
    private let durationPenaltyRate = 10.0

    // Deep sleep thresholds (ratio)
    private let idealDeepSleepRange = 0.15...0.25
    private let idealDeepSleepCenter = 0.20
    private let deepSleepPenaltyRate = 100.0

    // REM sleep thresholds (ratio)
    private let idealREMSleepRange = 0.20...0.25
    private let idealREMSleepCenter = 0.225
    private let remSleepPenaltyRate = 75.0

    private let wasoAnalyzer = AnalyzeWASOUseCase()

    struct Input: Sendable {
        let stages: [SleepStage]
    }

    struct Output: Sendable {
        let score: Int
        let totalMinutes: Double
        let efficiency: Double
        let remRatio: Double
        let wasoMinutes: Double
        let wasoCount: Int
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
            return Output(score: 0, totalMinutes: 0, efficiency: 0, remRatio: 0, wasoMinutes: 0, wasoCount: 0)
        }

        let hours = totalMinutes / 60

        // Duration score (30pt)
        let durationScore: Double
        if idealDurationRange.contains(hours) {
            durationScore = durationMaxScore
        } else if acceptableDurationRange.contains(hours) {
            durationScore = durationMaxScore - durationPenaltyRate
        } else {
            durationScore = max(0, durationMaxScore - abs(hours - idealDurationCenter) * durationPenaltyRate)
        }

        // Deep sleep score (20pt)
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

        // REM sleep score (15pt)
        let remMinutes = input.stages
            .filter { $0.stage == .rem }
            .map(\.duration)
            .reduce(0, +) / 60.0
        let remRatio = remMinutes / totalMinutes
        let remScore: Double
        if idealREMSleepRange.contains(remRatio) {
            remScore = remSleepMaxScore
        } else {
            remScore = max(0, remSleepMaxScore - abs(remRatio - idealREMSleepCenter) * remSleepPenaltyRate)
        }

        // Efficiency score (20pt)
        let efficiencyScore = min(efficiencyMaxScore, efficiency / 100 * efficiencyMaxScore)

        // WASO score (15pt)
        let wasoAnalysis = wasoAnalyzer.execute(stages: input.stages)
        let wasoScore = Double(wasoAnalysis?.score ?? 100) / 100.0 * wasoMaxScore

        let score = Int(min(100, durationScore + deepScore + remScore + efficiencyScore + wasoScore))
        return Output(
            score: score,
            totalMinutes: totalMinutes,
            efficiency: efficiency,
            remRatio: remRatio,
            wasoMinutes: wasoAnalysis?.totalWASOMinutes ?? 0,
            wasoCount: wasoAnalysis?.awakeningCount ?? 0
        )
    }
}
