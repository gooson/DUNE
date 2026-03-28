import Foundation

protocol WASOAnalyzing: Sendable {
    func execute(stages: [SleepStage]) -> WakeAfterSleepOnset?
}

/// Analyzes Wake After Sleep Onset from sleep stage data.
///
/// Identifies awake periods >= 5 minutes between sleep onset (first non-awake stage)
/// and final wake (last non-awake stage end). Scores inversely with total WASO minutes.
struct AnalyzeWASOUseCase: WASOAnalyzing, Sendable {

    /// Minimum awakening duration to count (seconds).
    private let minimumAwakeningDuration: TimeInterval = 5 * 60

    /// WASO thresholds for scoring (minutes).
    private let perfectThreshold = 10.0
    private let poorThreshold = 30.0
    private let minimumScore = 20

    func execute(stages: [SleepStage]) -> WakeAfterSleepOnset? {
        let sleepStages = stages.filter { $0.stage != .awake }
        guard !sleepStages.isEmpty else { return nil }

        let sleepOnset = sleepStages.map(\.startDate).min()!
        let sleepEnd = sleepStages.map(\.endDate).max()!

        // Filter awake stages within sleep onset..sleep end, duration >= 5 min
        let significantAwakenings = stages.filter { stage in
            stage.stage == .awake
                && stage.startDate >= sleepOnset
                && stage.endDate <= sleepEnd
                && stage.duration >= minimumAwakeningDuration
        }

        let totalWASO = significantAwakenings.reduce(0.0) { $0 + $1.duration } / 60.0
        let longest = (significantAwakenings.map(\.duration).max() ?? 0) / 60.0
        let score = computeScore(totalWASOMinutes: totalWASO)

        return WakeAfterSleepOnset(
            awakeningCount: significantAwakenings.count,
            totalWASOMinutes: totalWASO,
            longestAwakeningMinutes: longest,
            score: score
        )
    }

    private func computeScore(totalWASOMinutes: Double) -> Int {
        guard totalWASOMinutes > perfectThreshold else { return 100 }
        guard totalWASOMinutes < poorThreshold else {
            // Linear decline from poorThreshold to 60 min → minimum score
            let excess = totalWASOMinutes - poorThreshold
            let maxExcess = 30.0 // 60 min total
            let ratio = min(1.0, excess / maxExcess)
            return max(minimumScore, Int(50.0 - ratio * 30.0))
        }
        // Linear from 100 to 50 between perfect and poor thresholds
        let ratio = (totalWASOMinutes - perfectThreshold) / (poorThreshold - perfectThreshold)
        return Int(100.0 - ratio * 50.0)
    }
}
