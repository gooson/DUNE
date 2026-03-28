import Foundation

protocol SleepDebtRecoveryPredicting: Sendable {
    func execute(deficit: SleepDeficitAnalysis) -> SleepDebtRecoveryPrediction?
}

/// Predicts recovery timeline from sleep debt using exponential decay model.
///
/// Model: Each night of adequate sleep reduces remaining debt by ~50%.
/// Recovery threshold: debt < 30 minutes.
struct PredictSleepDebtRecoveryUseCase: SleepDebtRecoveryPredicting, Sendable {

    /// Debt threshold below which recovery is considered complete (minutes).
    private let recoveryThreshold = 30.0

    /// Daily decay factor (50% recovery per night of adequate sleep).
    private let decayFactor = 0.5

    /// Maximum projection horizon (days).
    private let maxProjectionDays = 30

    func execute(deficit: SleepDeficitAnalysis) -> SleepDebtRecoveryPrediction? {
        guard deficit.level != .good, deficit.level != .insufficient else { return nil }
        guard deficit.weeklyDeficit > recoveryThreshold else { return nil }

        let currentDebt = deficit.weeklyDeficit
        var projections: [SleepDebtRecoveryPrediction.DayProjection] = []
        var recoveryDays = 0
        var remainingDebt = currentDebt

        for day in 0...maxProjectionDays {
            projections.append(.init(dayOffset: day, projectedDebtMinutes: remainingDebt))

            if remainingDebt <= recoveryThreshold {
                recoveryDays = day
                break
            }

            remainingDebt *= decayFactor

            if day == maxProjectionDays {
                recoveryDays = maxProjectionDays
            }
        }

        let rate: SleepDebtRecoveryPrediction.RecoveryRate = switch recoveryDays {
        case 0...3: .fast
        case 4...7: .moderate
        case 8...14: .slow
        default: .extended
        }

        return SleepDebtRecoveryPrediction(
            currentDebtMinutes: currentDebt,
            estimatedRecoveryDays: recoveryDays,
            dailyProjection: projections,
            recoveryRate: rate
        )
    }
}
