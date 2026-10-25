import Foundation

struct RunningFeedbackSettings: Equatable, Sendable {
    var distanceIntervalMeters: Double
    var volume: Double
    var paceAlertsEnabled: Bool
    var targetPaceSecondsPerKm: Double
    var paceToleranceSecondsPerKm: Double

    init(
        distanceIntervalMeters: Double = 1_000,
        volume: Double = 1,
        paceAlertsEnabled: Bool = false,
        targetPaceSecondsPerKm: Double = 360,
        paceToleranceSecondsPerKm: Double = 15
    ) {
        self.distanceIntervalMeters = [500, 1_000, 2_000].contains(distanceIntervalMeters)
            ? distanceIntervalMeters : 1_000
        self.volume = volume.isFinite ? min(max(volume, 0), 1) : 1
        self.paceAlertsEnabled = paceAlertsEnabled
        self.targetPaceSecondsPerKm = targetPaceSecondsPerKm.isFinite
            ? min(max(targetPaceSecondsPerKm, 120), 1_200) : 360
        self.paceToleranceSecondsPerKm = paceToleranceSecondsPerKm.isFinite
            ? min(max(paceToleranceSecondsPerKm, 5), 60) : 15
    }

    var normalized: Self {
        Self(
            distanceIntervalMeters: distanceIntervalMeters,
            volume: volume,
            paceAlertsEnabled: paceAlertsEnabled,
            targetPaceSecondsPerKm: targetPaceSecondsPerKm,
            paceToleranceSecondsPerKm: paceToleranceSecondsPerKm
        )
    }
}
