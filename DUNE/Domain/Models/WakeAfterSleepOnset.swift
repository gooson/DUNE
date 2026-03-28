import Foundation

/// Analysis of awakenings during the sleep period (after initial sleep onset).
struct WakeAfterSleepOnset: Sendable {
    /// Number of awakenings lasting >= 5 minutes.
    let awakeningCount: Int

    /// Total WASO duration in minutes.
    let totalWASOMinutes: Double

    /// Longest single awakening duration in minutes.
    let longestAwakeningMinutes: Double

    /// WASO-based quality score (0-100). Higher = fewer/shorter awakenings.
    let score: Int
}
