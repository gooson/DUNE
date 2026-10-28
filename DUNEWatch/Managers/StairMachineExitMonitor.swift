import CoreLocation
import Foundation

@MainActor
protocol StairExitLocationProviding: AnyObject {
    var delegate: (any CLLocationManagerDelegate)? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: StairExitLocationProviding {}

/// Coordinates stay in memory. Main-actor creation keeps delegate delivery on the main run loop.
@MainActor
final class StairMachineExitMonitor: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let locationManager: any StairExitLocationProviding
    private let startedAt: Date
    private var detector: StairMachineExitDetector
    private let steps: () -> Double
    private let onExit: () -> Void
    private var isMonitoring = false
    private var activationDate = Date()

    init(
        startedAt: Date,
        steps: @escaping () -> Double,
        onExit: @escaping () -> Void,
        locationManager: any StairExitLocationProviding = StairMachineExitMonitor.makeLocationManager()
    ) {
        self.startedAt = startedAt
        self.locationManager = locationManager
        detector = StairMachineExitDetector(startedAt: startedAt)
        self.steps = steps
        self.onExit = onExit
        super.init()
        locationManager.delegate = self
    }

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        updateAuthorization()
    }

    private func updateAuthorization() {
        guard isMonitoring else { return }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            // Do not carry a candidate across a permission gap or a precision change.
            detector = StairMachineExitDetector(startedAt: startedAt)
            activationDate = Date()
            locationManager.startUpdatingLocation()
        case .restricted, .denied:
            locationManager.stopUpdatingLocation()
        @unknown default:
            locationManager.stopUpdatingLocation()
        }
    }

    func stop() {
        isMonitoring = false
        detector.dismiss()
        locationManager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isMonitoring,
              locationManager.authorizationStatus == .authorizedWhenInUse
                || locationManager.authorizationStatus == .authorizedAlways else { return }
        let now = Date()
        for location in locations where location.timestamp >= activationDate {
            if detector.observe(location: location, steps: steps(), now: now) {
                stop()
                onExit()
                return
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Unavailable GPS is not evidence that the workout has ended.
        if let error = error as? CLError, error.code == .denied {
            locationManager.stopUpdatingLocation()
        }
    }

    private static func makeLocationManager() -> CLLocationManager {
        let manager = CLLocationManager()
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.allowsBackgroundLocationUpdates = true
        return manager
    }
}
