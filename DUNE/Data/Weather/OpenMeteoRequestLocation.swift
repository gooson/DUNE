import CoreLocation
import Foundation

struct OpenMeteoRequestLocation: Sendable, Hashable {
    let latitude: Double
    let longitude: Double

    init(location: CLLocation) {
        self.latitude = Self.normalizedCoordinate(location.coordinate.latitude)
        self.longitude = Self.normalizedCoordinate(location.coordinate.longitude)
    }

    private static func normalizedCoordinate(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
