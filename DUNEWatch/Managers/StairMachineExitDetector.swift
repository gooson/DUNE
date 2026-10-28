import CoreLocation
import Foundation

/// Suggests that a stair-machine workout may have continued into an outdoor walk.
/// Only measured GPS displacement is used; HealthKit's estimated distance is irrelevant.
struct StairMachineExitDetector {
    private let startedAt: Date
    private var anchor: CLLocation?
    private var anchorSteps: Double = 0
    private var previous: CLLocation?
    private var previousSteps: Double = 0
    private var previousNow: Date?
    private var sampleCount = 0
    private var hasRecommended = false
    private var isDismissed = false

    init(startedAt: Date) {
        self.startedAt = startedAt
    }

    mutating func observe(location: CLLocation, steps: Double, now: Date) -> Bool {
        guard !hasRecommended, !isDismissed,
              steps.isFinite, (0...200_000).contains(steps),
              location.horizontalAccuracy.isFinite,
              (0...20).contains(location.horizontalAccuracy),
              location.horizontalAccuracy > 0,
              location.coordinate.latitude.isFinite,
              location.coordinate.longitude.isFinite,
              CLLocationCoordinate2DIsValid(location.coordinate) else {
            return false
        }

        let age = now.timeIntervalSince(location.timestamp)
        guard age.isFinite, (-5...15).contains(age),
              now.timeIntervalSince(startedAt) >= 0 else {
            return false
        }

        if let previous, let previousNow {
            let interval = location.timestamp.timeIntervalSince(previous.timestamp)
            guard interval > 0, now >= previousNow else { return false }

            if interval > 30 || steps < previousSteps ||
                location.distance(from: previous) / interval > 4 {
                rebase(at: location, steps: steps, now: now)
                return false
            }
        }

        guard let anchor else {
            rebase(at: location, steps: steps, now: now)
            return false
        }

        previous = location
        previousSteps = steps
        previousNow = now
        sampleCount += 1

        let elapsed = location.timestamp.timeIntervalSince(anchor.timestamp)
        let netDisplacement = location.distance(from: anchor)
            - anchor.horizontalAccuracy - location.horizontalAccuracy
        guard now.timeIntervalSince(startedAt) >= 120,
              sampleCount >= 4,
              elapsed >= 60,
              netDisplacement >= 100,
              steps - anchorSteps >= 40 else {
            return false
        }

        hasRecommended = true
        return true
    }

    mutating func dismiss() {
        isDismissed = true
    }

    private mutating func rebase(at location: CLLocation, steps: Double, now: Date) {
        anchor = location
        anchorSteps = steps
        previous = location
        previousSteps = steps
        previousNow = now
        sampleCount = 1
    }
}
