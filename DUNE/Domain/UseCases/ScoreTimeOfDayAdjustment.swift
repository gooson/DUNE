import Foundation

/// Shared score adjustment profile by time of day.
enum ScoreTimeOfDayAdjustment {
    /// Readiness/Wellness profile aligned with Condition score diurnal pattern.
    static func readinessAndWellness(for date: Date) -> Double {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 0..<6: return 6
        case 6..<11: return 3
        case 11..<17: return 0
        case 17..<22: return -3
        default: return -1
        }
    }
}
