import Foundation

struct CalculateSleepScoreUseCase: Sendable {
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

        // Duration score (0-40): 7-9 hours ideal
        let hours = totalMinutes / 60
        let durationScore: Double
        if hours >= 7 && hours <= 9 {
            durationScore = 40
        } else if hours >= 6 || hours <= 10 {
            durationScore = 30
        } else {
            durationScore = max(0, 40 - abs(hours - 8) * 10)
        }

        // Deep sleep ratio score (0-30): 15-25% ideal
        let deepMinutes = input.stages
            .filter { $0.stage == .deep }
            .map(\.duration)
            .reduce(0, +) / 60.0
        let deepRatio = deepMinutes / totalMinutes
        let deepScore: Double
        if deepRatio >= 0.15 && deepRatio <= 0.25 {
            deepScore = 30
        } else {
            deepScore = max(0, 30 - abs(deepRatio - 0.20) * 150)
        }

        // Efficiency score (0-30)
        let efficiencyScore = min(30, efficiency / 100 * 30)

        let score = Int(min(100, durationScore + deepScore + efficiencyScore))
        return Output(score: score, totalMinutes: totalMinutes, efficiency: efficiency)
    }
}
