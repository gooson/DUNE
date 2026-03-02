import CoreLocation
import OSLog

/// GPS-based distance tracking using CLLocationManager.
/// Accumulates distance from successive location updates with accuracy filtering.
final class LocationTrackingService: NSObject, LocationTrackingServiceProtocol, @unchecked Sendable {
    private let logger = AppLogger.healthKit
    private let locationManager = CLLocationManager()
    private let lock = NSLock()

    private var lastLocation: CLLocation?
    private var _totalDistanceMeters: Double = 0
    private var isTracking = false

    var totalDistanceMeters: Double {
        lock.withLock { _totalDistanceMeters }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // meters — reduces battery drain
        locationManager.activityType = .fitness
    }

    func startTracking() async throws {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // Wait briefly for the authorization callback
            try await Task.sleep(for: .seconds(1))
        }

        let currentStatus = locationManager.authorizationStatus
        guard currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways else {
            throw LocationTrackingError.notAuthorized
        }

        lock.withLock {
            _totalDistanceMeters = 0
            lastLocation = nil
            isTracking = true
        }
        locationManager.startUpdatingLocation()
        logger.info("[Location] GPS tracking started")
    }

    func stopTracking() async -> Double {
        locationManager.stopUpdatingLocation()
        let distance: Double = lock.withLock {
            isTracking = false
            return _totalDistanceMeters
        }
        logger.info("[Location] GPS tracking stopped. Total: \(String(format: "%.0f", distance))m")
        return distance
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationTrackingService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lock.withLock {
            guard isTracking else { return }
            for location in locations {
                // Filter inaccurate readings (> 20m horizontal accuracy)
                guard location.horizontalAccuracy >= 0,
                      location.horizontalAccuracy < 20 else { continue }

                if let last = lastLocation {
                    let delta = location.distance(from: last)
                    // Ignore impossibly large jumps (> 100m between updates) — GPS glitch
                    if delta >= 0, delta < 100 {
                        _totalDistanceMeters += delta
                    }
                }
                lastLocation = location
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.warning("[Location] CLLocationManager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        logger.info("[Location] Authorization changed: \(manager.authorizationStatus.rawValue)")
    }
}

// MARK: - Error

enum LocationTrackingError: Error, LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAuthorized: String(localized: "Location permission is required for outdoor distance tracking.")
        }
    }
}
