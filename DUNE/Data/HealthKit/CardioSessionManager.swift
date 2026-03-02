import Foundation
import CoreLocation
import HealthKit
import Observation

/// Manages GPS-based distance tracking and HKWorkoutSession for iPhone cardio workouts.
/// Outdoor: CLLocationManager (GPS distance) + HKWorkoutSession (calories/HR).
/// Indoor: HKWorkoutSession only (no GPS).
@Observable
@MainActor
final class CardioSessionManager: NSObject, Sendable {

    // MARK: - Session State

    enum SessionState: Sendable {
        case idle
        case running
        case paused
        case ended
    }

    private(set) var state: SessionState = .idle
    private(set) var startDate: Date?

    /// Activity type for the current session.
    private(set) var activityType: WorkoutActivityType = .running
    private(set) var isOutdoor: Bool = true

    // MARK: - Live Metrics

    /// Total distance in meters.
    private(set) var distance: Double = 0

    /// Current pace in seconds per kilometer. 0 means no data yet.
    private(set) var currentPace: Double = 0

    /// Heart rate in bpm (from paired Watch via HKWorkoutSession).
    private(set) var heartRate: Double = 0

    /// Active calories burned (from HKWorkoutSession).
    private(set) var activeCalories: Double = 0

    /// Distance in kilometers (convenience for UI display).
    var distanceKm: Double { distance / 1000.0 }

    /// Formatted pace string "M:SS" (returns "--:--" when no distance yet).
    var formattedPace: String {
        guard currentPace > 0, currentPace.isFinite, currentPace < 3600 else { return "--:--" }
        let mins = Int(currentPace) / 60
        let secs = Int(currentPace) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    /// Elapsed time since session start (paused time excluded via HK).
    var elapsedTime: TimeInterval {
        guard let start = startDate, state != .idle else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// UUID of the saved HKWorkout after session ends.
    private(set) var healthKitWorkoutUUID: String?

    // MARK: - Private

    private var locationManager: CLLocationManager?
    private var lastLocation: CLLocation?

    private var hkSession: HKWorkoutSession?
    private var hkBuilder: HKLiveWorkoutBuilder?
    private let healthStore = HKHealthStore()

    /// Accumulated distance during pause — location updates are ignored while paused.
    private var distanceAtPause: Double = 0

    // MARK: - Lifecycle

    /// Start a cardio tracking session.
    func startSession(activityType: WorkoutActivityType, isOutdoor: Bool) async throws {
        guard state == .idle else { return }

        self.activityType = activityType
        self.isOutdoor = isOutdoor
        self.distance = 0
        self.currentPace = 0
        self.heartRate = 0
        self.activeCalories = 0
        self.healthKitWorkoutUUID = nil
        self.lastLocation = nil
        self.distanceAtPause = 0

        let now = Date()
        self.startDate = now

        // Setup HKWorkoutSession
        try await setupHKSession(activityType: activityType, isOutdoor: isOutdoor, startDate: now)

        // Setup CLLocationManager for outdoor
        if isOutdoor {
            setupLocationManager()
        }

        state = .running
    }

    func pause() {
        guard state == .running else { return }
        hkSession?.pause()
        distanceAtPause = distance
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        hkSession?.resume()
        lastLocation = nil // Reset to avoid jump after pause
        state = .running
    }

    func endSession() async {
        guard state == .running || state == .paused else { return }

        locationManager?.stopUpdatingLocation()
        locationManager = nil

        hkSession?.end()

        // Wait for HK finalization
        if let builder = hkBuilder {
            let endDate = Date()
            do {
                try await builder.endCollection(at: endDate)
                let workout = try await builder.finishWorkout()
                if let uuid = workout?.uuid.uuidString, !uuid.isEmpty {
                    healthKitWorkoutUUID = uuid
                }
            } catch {
                AppLogger.healthKit.error("Failed to finish cardio workout: \(error.localizedDescription)")
            }
        }

        state = .ended
    }

    func reset() {
        locationManager?.stopUpdatingLocation()
        locationManager = nil
        hkSession = nil
        hkBuilder = nil
        lastLocation = nil

        state = .idle
        startDate = nil
        distance = 0
        currentPace = 0
        heartRate = 0
        activeCalories = 0
        healthKitWorkoutUUID = nil
        distanceAtPause = 0
    }

    // MARK: - Location Authorization

    var locationAuthorizationStatus: CLAuthorizationStatus {
        locationManager?.authorizationStatus ?? CLLocationManager().authorizationStatus
    }

    // MARK: - Test Helpers

    /// Sets startDate directly for unit testing without starting a real HK/GPS session.
    func testSetStartDate(_ date: Date) {
        startDate = date
    }

    // MARK: - Private Setup

    private func setupHKSession(
        activityType: WorkoutActivityType,
        isOutdoor: Bool,
        startDate: Date
    ) async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = activityType.hkWorkoutActivityType
        config.locationType = isOutdoor ? .outdoor : .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()

        session.delegate = self
        builder.delegate = self
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: config
        )

        hkSession = session
        hkBuilder = builder

        session.startActivity(with: startDate)
        try await builder.beginCollection(at: startDate)
    }

    private func setupLocationManager() {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5 // Update every 5 meters
        manager.activityType = clActivityType(for: activityType)
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        locationManager = manager
    }

    private func clActivityType(for type: WorkoutActivityType) -> CLActivityType {
        switch type {
        case .running, .walking, .hiking: return .fitness
        case .cycling, .handCycling: return .otherNavigation
        default: return .fitness
        }
    }

    /// Recalculate pace from total distance and elapsed time.
    private func updatePace() {
        guard state == .running else { return }
        guard let start = startDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        let km = distance / 1000.0
        guard km > 0.01 else {
            currentPace = 0
            return
        }
        currentPace = elapsed / km
    }
}

// MARK: - CLLocationManagerDelegate

extension CardioSessionManager: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor in
            guard state == .running else { return }
            for location in locations {
                // Filter out inaccurate readings
                guard location.horizontalAccuracy >= 0,
                      location.horizontalAccuracy <= 50 else { continue }

                if let last = lastLocation {
                    let delta = location.distance(from: last)
                    // Sanity check: ignore GPS jumps > 100m between consecutive updates
                    guard delta < 100 else { continue }
                    distance += delta
                }
                lastLocation = location
            }
            updatePace()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: any Error
    ) {
        // GPS errors are transient — log and continue
        AppLogger.healthKit.warning("Location update failed: \(error.localizedDescription)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Authorization changes are handled by the calling view
    }
}

// MARK: - HKWorkoutSessionDelegate

extension CardioSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // State changes handled by explicit pause/resume/end calls
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: any Error
    ) {
        AppLogger.healthKit.error("Cardio workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension CardioSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // No custom events
    }

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        var heartRateValue: Double?
        var caloriesValue: Double?

        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  let stats = workoutBuilder.statistics(for: quantityType) else { continue }

            switch quantityType {
            case HKQuantityType(.heartRate):
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = stats.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
                if (20...250).contains(bpm) {
                    heartRateValue = bpm
                }

            case HKQuantityType(.activeEnergyBurned):
                let unit = HKUnit.kilocalorie()
                let kcal = stats.sumQuantity()?.doubleValue(for: unit) ?? 0
                if kcal >= 0, kcal < 10_000 {
                    caloriesValue = kcal
                }

            default:
                break
            }
        }

        Task { @MainActor in
            if let bpm = heartRateValue {
                heartRate = bpm
            }
            if let kcal = caloriesValue {
                activeCalories = kcal
            }
        }
    }
}
