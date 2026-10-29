import Foundation

/// Domain-level protocol for GPS location tracking.
/// Concrete implementation lives in Data/Location/ (CLLocationManager).
protocol LocationTrackingServiceProtocol: Sendable {
    /// Start tracking location updates.
    func startTracking() async throws
    /// Stop tracking and return final accumulated distance in meters.
    func stopTracking() async -> Double
    var routePoints: [WorkoutRoutePoint] { get }
    func pauseTracking()
    func resumeTracking()
    /// Current accumulated distance in meters (thread-safe, synchronous read).
    var totalDistanceMeters: Double { get }
    /// Current accumulated elevation gain in meters (thread-safe, synchronous read).
    var totalElevationGainMeters: Double { get }
}

// Existing distance-only providers and mocks remain source compatible.
extension LocationTrackingServiceProtocol {
    var routePoints: [WorkoutRoutePoint] { [] }
    func pauseTracking() {}
    func resumeTracking() {}
}
