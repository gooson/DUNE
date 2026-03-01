import CoreLocation
import Foundation

/// Protocol for air quality data fetching (testable).
protocol AirQualityFetching: Sendable {
    func fetchAirQuality(for location: CLLocation) async throws -> AirQualitySnapshot
}
