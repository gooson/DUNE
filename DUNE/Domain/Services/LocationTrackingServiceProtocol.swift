import Foundation

/// Domain-level protocol for GPS location tracking.
/// Concrete implementation lives in Data/Location/ (CLLocationManager).
protocol LocationTrackingServiceProtocol: Sendable {
    /// Start tracking location updates.
    func startTracking() async throws
    /// Stop tracking and return final accumulated distance in meters.
    func stopTracking() async -> Double
    /// Current accumulated distance in meters.
    var totalDistanceMeters: Double { get async }
}
