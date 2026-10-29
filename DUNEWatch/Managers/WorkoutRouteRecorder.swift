import CoreLocation
import Foundation
import HealthKit
import OSLog

@MainActor
protocol WorkoutRouteLocationProviding: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: WorkoutRouteLocationProviding {}

/// Collects real Watch GPS points only. HealthKit remains the source of workout distance.
@MainActor
final class WorkoutRouteRecorder: NSObject, CLLocationManagerDelegate {
    private let locationManager: any WorkoutRouteLocationProviding
    private(set) var points: [WorkoutRoutePoint] = []
    private(set) var isRecording = false
    private(set) var isPaused = false
    private var acceptsSamplesFrom: Date?
    private var previousPoint: WorkoutRoutePoint?
    private var isUpdatingLocation = false

    init(locationManager: any WorkoutRouteLocationProviding = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        locationManager.delegate = self
        if let manager = locationManager as? CLLocationManager {
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.distanceFilter = 10
            manager.activityType = .fitness
            // The Watch target declares location + workout-processing background modes.
            manager.allowsBackgroundLocationUpdates = true
        }
    }

    static func shouldRecord(mode: WorkoutMode) -> Bool {
        if case .cardio(_, let isOutdoor) = mode { return isOutdoor }
        return false
    }

    func start(at date: Date) {
        cancel()
        points = []
        acceptsSamplesFrom = date
        isRecording = true
        applyAuthorization(locationManager.authorizationStatus, requestsPermission: true)
    }

    func pause(at date: Date) {
        guard isRecording else { return }
        isPaused = true
        previousPoint = nil
        stopUpdates()
    }

    func resume(at date: Date) {
        guard isRecording, isPaused else { return }
        isPaused = false
        acceptsSamplesFrom = date
        previousPoint = nil
        applyAuthorization(locationManager.authorizationStatus, requestsPermission: false)
    }

    func stop() -> [WorkoutRoutePoint] {
        isRecording = false
        isPaused = false
        acceptsSamplesFrom = nil
        previousPoint = nil
        stopUpdates()
        return WorkoutLocationPayload.normalizedRoute(points)
    }

    func cancel() {
        _ = stop()
        points = []
    }

    private func stopUpdates() {
        locationManager.stopUpdatingLocation()
        isUpdatingLocation = false
    }

    private func applyAuthorization(_ status: CLAuthorizationStatus, requestsPermission: Bool) {
        guard isRecording, !isPaused else { return }
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            guard !isUpdatingLocation else { return }
            isUpdatingLocation = true
            locationManager.startUpdatingLocation()
        case .notDetermined:
            if requestsPermission { locationManager.requestWhenInUseAuthorization() }
        default:
            previousPoint = nil
            stopUpdates()
        }
    }

    /// Internal entry point allows deterministic lifecycle/sensor validation without GPS hardware.
    func receive(_ locations: [CLLocation], at now: Date) {
        guard isRecording, !isPaused, isUpdatingLocation, let acceptsSamplesFrom else { return }
        for location in locations {
            guard location.timestamp >= acceptsSamplesFrom,
                  location.timestamp <= now.addingTimeInterval(1),
                  now.timeIntervalSince(location.timestamp) <= 15,
                  location.horizontalAccuracy >= 0, location.horizontalAccuracy < 20,
                  var point = WorkoutRoutePoint(
                    latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                    timestamp: location.timestamp,
                    altitude: location.verticalAccuracy >= 0 ? location.altitude : nil,
                    horizontalAccuracy: location.horizontalAccuracy
                  ) else { previousPoint = nil; continue }
            point.startsNewSegment = previousPoint == nil
            if let previousPoint {
                let interval = point.timestamp.timeIntervalSince(previousPoint.timestamp)
                guard interval > 0 else { continue }
                point.startsNewSegment = interval > 30 || previousPoint.distance(to: point) >= 100
            }
            points.append(point)
            previousPoint = point
            if points.count > WorkoutLocationPayload.maxRoutePoints {
                points = WorkoutLocationPayload.normalizedRoute(points, limit: WorkoutLocationPayload.maxRoutePoints / 2)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in self?.receive(locations, at: Date()) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in self?.authorizationChanged(status) }
    }

    func authorizationChanged(_ status: CLAuthorizationStatus) {
        applyAuthorization(status, requestsPermission: false)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.previousPoint = nil }
    }
}

@MainActor
protocol WorkoutRouteSegmentWriting: AnyObject {
    func write(_ points: [WorkoutRoutePoint]) async throws
    func cancel()
}

/// One-shot bridge for HK callbacks, including cancellation before registration and late callbacks.
/// The callback retains only this small gate; completion clears its continuation immediately.
final class WorkoutRouteCallbackGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, any Error>?
    private var result: Result<Void, any Error>?

    @discardableResult
    func register(_ continuation: CheckedContinuation<Void, any Error>) -> Bool {
        let completed: Result<Void, any Error>? = lock.withLock {
            if let result { return result }
            self.continuation = continuation
            return nil
        }
        if let completed {
            continuation.resume(with: completed)
            return false
        }
        return true
    }

    func resolve(_ result: Result<Void, any Error>) {
        let pending: CheckedContinuation<Void, any Error>? = lock.withLock {
            guard self.result == nil else { return nil }
            self.result = result
            let pending = continuation
            continuation = nil
            return pending
        }
        pending?.resume(with: result)
    }

    func cancel() { resolve(.failure(CancellationError())) }
}

/// Writes one distinct HK route per continuous segment, after the workout itself is saved.
@MainActor
final class HealthKitWorkoutRouteSegmentWriter: WorkoutRouteSegmentWriting {
    private let store: HKHealthStore
    private let workout: HKWorkout
    private var activeBuilder: HKWorkoutRouteBuilder?
    private var pendingCallback: WorkoutRouteCallbackGate?

    init(store: HKHealthStore, workout: HKWorkout) {
        self.store = store
        self.workout = workout
    }

    func write(_ points: [WorkoutRoutePoint]) async throws {
        try Task.checkCancellation()
        guard store.authorizationStatus(for: HKSeriesType.workoutRoute()) == .sharingAuthorized else { return }
        let locations = points.filter { $0.timestamp >= workout.startDate && $0.timestamp <= workout.endDate }.map {
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                       altitude: $0.altitude ?? 0, horizontalAccuracy: $0.horizontalAccuracy ?? 10,
                       verticalAccuracy: $0.altitude == nil ? -1 : 10, timestamp: $0.timestamp)
        }
        guard locations.count >= 2 else { return }
        let builder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
        activeBuilder = builder
        defer {
            activeBuilder?.discard()
            activeBuilder = nil
        }
        try await awaitCallback { completion in
            builder.insertRouteData(locations) { success, error in
                if let error { completion(.failure(error)) }
                else if success { completion(.success(())) }
                else { completion(.failure(RouteWriteError.missingResult)) }
            }
        }
        try Task.checkCancellation()
        let workout = workout
        try await awaitCallback { completion in
            builder.finishRoute(with: workout, metadata: nil) { route, error in
                if let error { completion(.failure(error)) }
                else if route != nil { completion(.success(())) }
                else { completion(.failure(RouteWriteError.missingResult)) }
            }
        }
        activeBuilder = nil
    }

    private func awaitCallback(
        _ operation: (@escaping @Sendable (Result<Void, any Error>) -> Void) -> Void
    ) async throws {
        let gate = WorkoutRouteCallbackGate()
        pendingCallback = gate
        defer { pendingCallback = nil }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                guard gate.register(continuation) else { return }
                guard !Task.isCancelled else { gate.cancel(); return }
                operation { result in gate.resolve(result) }
            }
        } onCancel: {
            gate.cancel()
        }
    }

    func cancel() {
        pendingCallback?.cancel()
        pendingCallback = nil
        let builder = activeBuilder
        activeBuilder = nil
        builder?.discard()
    }

    private enum RouteWriteError: Error { case missingResult }
}

/// Optional route enrichment has its own deadline; it never holds up workout finalization.
@MainActor
final class WorkoutRouteSaveJob {
    private static let logger = Logger(subsystem: "com.raftel.dailve", category: "WatchWorkoutRoute")
    private let writer: any WorkoutRouteSegmentWriting
    private let segments: [[WorkoutRoutePoint]]
    private let onCompletion: @MainActor () -> Void
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private(set) var isFinished = false

    init(points: [WorkoutRoutePoint], writer: any WorkoutRouteSegmentWriting,
         onCompletion: @escaping @MainActor () -> Void) {
        self.segments = Self.segments(points)
        self.writer = writer
        self.onCompletion = onCompletion
    }

    static func segments(_ points: [WorkoutRoutePoint]) -> [[WorkoutRoutePoint]] {
        var segments: [[WorkoutRoutePoint]] = []
        for point in WorkoutLocationPayload.normalizedRoute(points) {
            if point.startsNewSegment || segments.isEmpty { segments.append([]) }
            segments[segments.count - 1].append(point)
        }
        return segments.filter { $0.count >= 2 }
    }

    func start(timeout: TimeInterval = 5) {
        guard operationTask == nil, !isFinished else { return }
        let writer = writer
        operationTask = Task { @MainActor [weak self, writer] in
            do {
                var index = 0
                // Do not retain the job (or its remaining segments) across an external await.
                while let segment = self?.segment(at: index) {
                    try Task.checkCancellation()
                    try await writer.write(segment)
                    index += 1
                }
            } catch {
                Self.logger.warning("Workout saved; optional Watch route write failed: \(error.localizedDescription, privacy: .public)")
            }
            self?.finish()
        }
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    func cancel() { finish() }

    private func segment(at index: Int) -> [WorkoutRoutePoint]? {
        guard !isFinished, segments.indices.contains(index) else { return nil }
        return segments[index]
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        operationTask?.cancel()
        operationTask = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        writer.cancel()
        onCompletion()
    }
}
