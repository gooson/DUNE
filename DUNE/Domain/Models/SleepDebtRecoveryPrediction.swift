import Foundation

/// Prediction of how many days it will take to recover from current sleep debt.
struct SleepDebtRecoveryPrediction: Sendable {
    /// Current sleep debt in minutes.
    let currentDebtMinutes: Double

    /// Estimated number of days to recover to acceptable level (<30 min debt).
    let estimatedRecoveryDays: Int

    /// Daily projected debt curve (day 0 = today).
    let dailyProjection: [DayProjection]

    /// Recovery speed classification.
    let recoveryRate: RecoveryRate

    struct DayProjection: Sendable, Identifiable {
        var id: Int { dayOffset }
        let dayOffset: Int
        let projectedDebtMinutes: Double
    }

    enum RecoveryRate: String, Sendable {
        case fast       // <= 3 days
        case moderate   // 4-7 days
        case slow       // 8-14 days
        case extended   // > 14 days

        var displayName: String {
            switch self {
            case .fast: String(localized: "Fast")
            case .moderate: String(localized: "Moderate")
            case .slow: String(localized: "Slow")
            case .extended: String(localized: "Extended")
            }
        }
    }
}
