import Foundation

/// Computes recovery modifiers from sleep quality and HRV/RHR data.
protocol RecoveryModifying: Sendable {
    /// Sleep-based recovery modifier. Higher value = faster recovery.
    func calculateSleepModifier(
        totalSleepMinutes: Double?,
        deepSleepRatio: Double?,
        remSleepRatio: Double?
    ) -> Double

    /// HRV/RHR-based readiness modifier. Higher value = faster recovery.
    func calculateReadinessModifier(
        hrvZScore: Double?,
        rhrDelta: Double?
    ) -> Double
}

struct RecoveryModifierService: RecoveryModifying, Sendable {

    // MARK: - Sleep Modifier

    /// Returns a modifier (0.5...1.25) based on last night's sleep.
    /// Returns 1.0 if sleep data is unavailable.
    func calculateSleepModifier(
        totalSleepMinutes: Double?,
        deepSleepRatio: Double?,
        remSleepRatio: Double?
    ) -> Double {
        guard let minutes = totalSleepMinutes,
              minutes.isFinite, minutes >= 0, minutes <= 1440 else {
            return 1.0
        }

        let hours = minutes / 60.0

        let baseFactor: Double
        switch hours {
        case 8...:     baseFactor = 1.15
        case 7..<8:    baseFactor = 1.0
        case 6..<7:    baseFactor = 0.85
        case 5..<6:    baseFactor = 0.70
        default:        baseFactor = 0.55
        }

        var qualityBonus = 0.0

        if let deep = deepSleepRatio, deep.isFinite, deep >= 0, deep <= 1.0 {
            if deep >= 0.20 {
                qualityBonus += 0.05
            } else if deep < 0.10 {
                qualityBonus -= 0.05
            }
        }

        if let rem = remSleepRatio, rem.isFinite, rem >= 0, rem <= 1.0 {
            if rem >= 0.20 {
                qualityBonus += 0.05
            } else if rem < 0.10 {
                qualityBonus -= 0.05
            }
        }

        return Swift.max(0.5, Swift.min(baseFactor + qualityBonus, 1.25))
    }

    // MARK: - Readiness Modifier

    /// Returns a modifier (0.6...1.20) based on HRV z-score and RHR delta.
    /// Returns 1.0 if HRV/RHR data is unavailable.
    func calculateReadinessModifier(
        hrvZScore: Double?,
        rhrDelta: Double?
    ) -> Double {
        guard let z = hrvZScore, z.isFinite else {
            // No HRV data — check RHR alone
            if let delta = rhrDelta, delta.isFinite {
                if delta >= 5 { return 0.85 }
                if delta <= -2 { return 1.05 }
            }
            return 1.0
        }

        var modifier: Double
        switch z {
        case 1.0...:           modifier = 1.15
        case 0..<1.0:          modifier = 1.05
        case -0.5..<0:         modifier = 1.0
        case -1.0..<(-0.5):    modifier = 0.85
        default:                modifier = 0.70
        }

        if let delta = rhrDelta, delta.isFinite {
            if delta >= 5 {
                modifier = Swift.min(modifier, 0.75)
            } else if delta <= -2 {
                modifier = Swift.min(modifier + 0.05, 1.20)
            }
        }

        return Swift.max(0.6, Swift.min(modifier, 1.20))
    }
}
