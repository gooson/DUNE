import Foundation

extension Double {
    /// Clamp to physical temperature range (-50°C to 60°C).
    /// Returns 20°C as safe fallback for NaN/Infinity.
    func clampedToPhysicalTemperature() -> Double {
        guard isFinite else { return 20 }
        return Swift.max(-50, Swift.min(60, self))
    }
}
