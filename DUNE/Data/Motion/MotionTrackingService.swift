import CoreMotion
import Foundation

/// CMPedometer-backed motion tracking for steps/cadence/pace/floors.
final class MotionTrackingService: MotionTrackingServiceProtocol, @unchecked Sendable {
    private let pedometer = CMPedometer()
    private let lock = NSLock()

    private var trackingStartDate: Date?
    private var isTracking = false
    private var _latestSnapshot: MotionTrackingSnapshot = .empty

    var latestSnapshot: MotionTrackingSnapshot {
        lock.withLock { _latestSnapshot }
    }

    func startTracking(from startDate: Date) async throws {
        guard CMPedometer.isStepCountingAvailable() else {
            throw MotionTrackingError.notAvailable
        }

        let authStatus = CMPedometer.authorizationStatus()
        guard authStatus != .denied, authStatus != .restricted else {
            throw MotionTrackingError.notAuthorized
        }

        lock.withLock {
            trackingStartDate = startDate
            isTracking = true
            _latestSnapshot = .empty
        }

        pedometer.startUpdates(from: startDate) { [weak self] data, error in
            guard let self else { return }
            if let error {
                AppLogger.healthKit.warning("[Motion] Pedometer update failed: \(error.localizedDescription)")
                return
            }
            guard let data else { return }
            let snapshot = Self.makeSnapshot(from: data)
            self.lock.withLock {
                guard self.isTracking else { return }
                self._latestSnapshot = Self.merge(base: self._latestSnapshot, incoming: snapshot)
            }
        }
    }

    func stopTracking() async -> MotionTrackingSnapshot {
        pedometer.stopUpdates()

        let startDate = lock.withLock { () -> Date? in
            isTracking = false
            return trackingStartDate
        }

        guard let startDate else {
            return latestSnapshot
        }

        let finalSnapshot: MotionTrackingSnapshot? = await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: startDate, to: Date()) { data, error in
                if let error {
                    AppLogger.healthKit.warning("[Motion] Final pedometer query failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: Self.makeSnapshot(from: data))
            }
        }

        guard let finalSnapshot else {
            return latestSnapshot
        }

        return lock.withLock {
            let merged = Self.merge(base: _latestSnapshot, incoming: finalSnapshot)
            _latestSnapshot = merged
            return merged
        }
    }
}

private extension MotionTrackingService {
    static func makeSnapshot(from data: CMPedometerData) -> MotionTrackingSnapshot {
        let steps = max(0, data.numberOfSteps.intValue)

        let distanceMeters: Double? = {
            guard let value = data.distance?.doubleValue,
                  value > 0, value.isFinite, value < 500_000 else { return nil }
            return value
        }()

        let currentPaceSecondsPerKm: Double? = {
            guard let value = data.currentPace?.doubleValue else { return nil }
            let secPerKm = value * 1000.0
            guard secPerKm > 30, secPerKm.isFinite, secPerKm < 7_200 else { return nil }
            return secPerKm
        }()

        let averagePaceSecondsPerKm: Double? = {
            guard let value = data.averageActivePace?.doubleValue else { return nil }
            let secPerKm = value * 1000.0
            guard secPerKm > 30, secPerKm.isFinite, secPerKm < 7_200 else { return nil }
            return secPerKm
        }()

        let cadenceStepsPerMinute: Double? = {
            guard let value = data.currentCadence?.doubleValue else { return nil }
            let cadence = value * 60.0
            guard cadence > 20, cadence.isFinite, cadence < 300 else { return nil }
            return cadence
        }()

        let floorsAscended: Double? = {
            guard let value = data.floorsAscended?.doubleValue,
                  value >= 0, value.isFinite, value < 20_000 else { return nil }
            return value
        }()

        return MotionTrackingSnapshot(
            stepCount: steps,
            distanceMeters: distanceMeters,
            currentPaceSecondsPerKm: currentPaceSecondsPerKm,
            averagePaceSecondsPerKm: averagePaceSecondsPerKm,
            cadenceStepsPerMinute: cadenceStepsPerMinute,
            floorsAscended: floorsAscended
        )
    }

    static func merge(base: MotionTrackingSnapshot, incoming: MotionTrackingSnapshot) -> MotionTrackingSnapshot {
        MotionTrackingSnapshot(
            stepCount: max(base.stepCount, incoming.stepCount),
            distanceMeters: incoming.distanceMeters ?? base.distanceMeters,
            currentPaceSecondsPerKm: incoming.currentPaceSecondsPerKm ?? base.currentPaceSecondsPerKm,
            averagePaceSecondsPerKm: incoming.averagePaceSecondsPerKm ?? base.averagePaceSecondsPerKm,
            cadenceStepsPerMinute: incoming.cadenceStepsPerMinute ?? base.cadenceStepsPerMinute,
            floorsAscended: incoming.floorsAscended ?? base.floorsAscended
        )
    }
}
