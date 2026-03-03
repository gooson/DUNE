import Foundation

/// Normalized snapshot of motion metrics captured during a cardio session.
struct MotionTrackingSnapshot: Sendable {
    let stepCount: Int
    let distanceMeters: Double?
    let currentPaceSecondsPerKm: Double?
    let averagePaceSecondsPerKm: Double?
    let cadenceStepsPerMinute: Double?
    let floorsAscended: Double?

    static let empty = MotionTrackingSnapshot(
        stepCount: 0,
        distanceMeters: nil,
        currentPaceSecondsPerKm: nil,
        averagePaceSecondsPerKm: nil,
        cadenceStepsPerMinute: nil,
        floorsAscended: nil
    )
}

/// Domain-level protocol for CMPedometer-backed motion tracking.
protocol MotionTrackingServiceProtocol: Sendable {
    /// Start tracking from the given start date.
    func startTracking(from startDate: Date) async throws
    /// Stop tracking and return the latest/final snapshot.
    func stopTracking() async -> MotionTrackingSnapshot
    /// Current motion snapshot (thread-safe, synchronous read).
    var latestSnapshot: MotionTrackingSnapshot { get }
}

enum MotionTrackingError: Error, LocalizedError {
    case notAvailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            String(localized: "Motion tracking is not available on this device.")
        case .notAuthorized:
            String(localized: "Motion permission is required to track steps and cadence.")
        }
    }
}
