import Foundation

/// Muscle fatigue state computed from recent training history
struct MuscleFatigueState: Sendable {
    let muscle: MuscleGroup
    /// Last trained date (nil if never trained)
    let lastTrainedDate: Date?
    /// Hours since last trained (nil if never trained)
    let hoursSinceLastTrained: Double?
    /// Total sets targeting this muscle in the last 7 days
    let weeklyVolume: Int
    /// Recovery percentage (0.0 = just trained, 1.0 = fully recovered)
    let recoveryPercent: Double

    var isRecovered: Bool { recoveryPercent >= 0.8 }
    var isOverworked: Bool { weeklyVolume >= 20 }

    /// Estimated date when this muscle will be fully recovered. nil if already recovered or never trained.
    var nextReadyDate: Date? {
        guard let lastTrained = lastTrainedDate, muscle.recoveryHours > 0 else { return nil }
        let recoverySeconds = muscle.recoveryHours * 3600
        guard recoverySeconds.isFinite, !recoverySeconds.isNaN else { return nil }
        let readyDate = lastTrained.addingTimeInterval(recoverySeconds)
        return readyDate > Date() ? readyDate : nil
    }
}
