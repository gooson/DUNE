import CoreLocation
import Foundation
import HealthKit
import Testing
@testable import DUNEWatch

@Suite("Watch workout routes")
@MainActor
struct WorkoutRouteRecorderTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private final class LocationProvider: WorkoutRouteLocationProviding {
        var delegate: CLLocationManagerDelegate?
        var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
        var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
        var distanceFilter: CLLocationDistance = 10
        var allowsBackgroundLocationUpdates = true
        var location: CLLocation?
        var onLocationRequest: (() -> Void)?
        var requestCount = 0
        var requestLocationCount = 0
        var startCount = 0
        var stopCount = 0
        func requestWhenInUseAuthorization() { requestCount += 1 }
        func requestLocation() {
            requestLocationCount += 1
            onLocationRequest?()
        }
        func startUpdatingLocation() { startCount += 1 }
        func stopUpdatingLocation() { stopCount += 1 }
    }

    private func location(_ offset: Double, longitude: Double = 127, accuracy: Double = 5) -> CLLocation {
        CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37, longitude: longitude), altitude: 30,
                   horizontalAccuracy: accuracy, verticalAccuracy: 5, timestamp: date.addingTimeInterval(offset))
    }

    @Test("Only outdoor cardio is eligible for new route recording")
    func modePolicy() {
        #expect(!WorkoutRouteRecorder.shouldRecord(mode: .strength))
        #expect(!WorkoutRouteRecorder.shouldRecord(mode: .cardio(activityType: .running, isOutdoor: false)))
        for type: WorkoutActivityType in [.running, .walking, .cycling, .hiking, .swimming] {
            #expect(WorkoutRouteRecorder.shouldRecord(mode: .cardio(activityType: type, isOutdoor: true)))
        }
    }

    @Test("Permission is requested once; denial and a late grant after stop never start GPS")
    func authorizationLifecycle() {
        let provider = LocationProvider()
        provider.authorizationStatus = .notDetermined
        let recorder = WorkoutRouteRecorder(locationManager: provider)
        recorder.start(at: date)
        #expect(provider.requestCount == 1)
        #expect(provider.startCount == 0)
        recorder.authorizationChanged(.denied)
        #expect(provider.startCount == 0)
        #expect(recorder.stop().isEmpty)
        recorder.authorizationChanged(.authorizedWhenInUse)
        #expect(provider.startCount == 0)
    }

    @Test("Indoor cardio captures one place without generating a route")
    func indoorPlaceCapture() throws {
        #expect(WorkoutRouteRecorder.shouldCapturePlace(mode: .cardio(activityType: .running, isOutdoor: false)))
        #expect(WorkoutRouteRecorder.shouldCapturePlace(mode: .cardio(activityType: .stairClimbing, isOutdoor: false)))
        #expect(!WorkoutRouteRecorder.shouldCapturePlace(mode: .cardio(activityType: .running, isOutdoor: true)))
        #expect(!WorkoutRouteRecorder.shouldCapturePlace(mode: .strength))
        let provider = LocationProvider()
        let recorder = WorkoutRouteRecorder(locationManager: provider)
        recorder.start(at: date, capturesPlaceOnly: true)
        #expect(provider.desiredAccuracy == kCLLocationAccuracyHundredMeters)
        #expect(provider.distanceFilter == kCLDistanceFilterNone)
        #expect(!provider.allowsBackgroundLocationUpdates)
        #expect(provider.requestLocationCount == 1)
        #expect(provider.startCount == 0)
        recorder.receive([location(-1), location(1, accuracy: 101)], at: date.addingTimeInterval(1))
        #expect(recorder.capturedPlace == nil)
        recorder.receive([location(2, accuracy: 100)], at: date.addingTimeInterval(2))
        let place = try #require(recorder.capturedPlace)
        #expect(place.latitude == 37)
        #expect(place.longitude == 127)
        #expect(place.source == .gps)
        #expect(place.name.isEmpty)
        #expect(!recorder.isRecording)
        #expect(recorder.stop().isEmpty)
        recorder.resume(at: date.addingTimeInterval(3))
        recorder.authorizationChanged(.authorizedWhenInUse)
        recorder.receive([location(4, longitude: 128)], at: date.addingTimeInterval(4))
        #expect(recorder.capturedPlace == place)
        #expect(provider.requestLocationCount == 1)
        #expect(provider.startCount == 0)
        recorder.cancel()
        #expect(recorder.capturedPlace == nil)
    }

    @Test("Ending indoor capture ignores late permission or sensor callbacks")
    func indoorPlaceStop() {
        let provider = LocationProvider()
        provider.authorizationStatus = .notDetermined
        let recorder = WorkoutRouteRecorder(locationManager: provider)
        recorder.start(at: date, capturesPlaceOnly: true)
        #expect(provider.requestCount == 1)
        #expect(provider.requestLocationCount == 0)
        _ = recorder.stop()
        recorder.authorizationChanged(.authorizedAlways)
        recorder.receive([location(31)], at: date.addingTimeInterval(31))
        #expect(provider.startCount == 0)
        #expect(provider.requestLocationCount == 0)
        #expect(recorder.capturedPlace == nil)
        #expect(recorder.stop().isEmpty)
    }

    @Test("Duplicate authorization callbacks do not start extra requests")
    func indoorPlaceAuthorization() {
        let provider = LocationProvider()
        provider.authorizationStatus = .notDetermined
        let recorder = WorkoutRouteRecorder(locationManager: provider)
        recorder.start(at: date, capturesPlaceOnly: true)
        #expect(provider.requestCount == 1)
        #expect(provider.requestLocationCount == 0)
        recorder.authorizationChanged(.authorizedWhenInUse)
        recorder.authorizationChanged(.authorizedWhenInUse)
        #expect(provider.requestLocationCount == 1)
        recorder.pause(at: date.addingTimeInterval(1))
        recorder.authorizationChanged(.authorizedWhenInUse)
        #expect(provider.requestLocationCount == 1)
        recorder.resume(at: date.addingTimeInterval(2))
        recorder.authorizationChanged(.authorizedWhenInUse)
        #expect(provider.requestLocationCount == 2)
        #expect(provider.startCount == 0)
        recorder.cancel()
    }

    @Test("A failed or inaccurate first indoor fix is retried until one valid place is saved")
    func retryIndoorPlace() async throws {
        let provider = LocationProvider()
        let recorder = WorkoutRouteRecorder(locationManager: provider, initialPlaceRetryDelay: .milliseconds(5))
        defer { recorder.cancel() }
        let goodFix = location(3)
        provider.onLocationRequest = {
            if provider.requestLocationCount == 3 {
                recorder.receive([goodFix], at: goodFix.timestamp)
            }
        }
        defer { provider.onLocationRequest = nil }
        recorder.start(at: date, capturesPlaceOnly: true)
        recorder.receive([location(-1), location(1, accuracy: 180)], at: date.addingTimeInterval(1))
        // The second request gets no callback.
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while recorder.capturedPlace == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        let place = try #require(recorder.capturedPlace)
        #expect(recorder.stop().isEmpty)
        try await WorkoutPlaceMetadataWrite.write(place: place, timeout: .seconds(1)) { metadata, completion in
            #expect(WorkoutPlaceMetadata.place(from: metadata) == place)
            completion(true, nil)
        }
        try await Task.sleep(for: .milliseconds(35))
        #expect(provider.requestLocationCount == 3)
        #expect(provider.startCount == 0)
    }

    @Test("Pause, revoked permission and stop cancel pending indoor retries")
    func cancelIndoorRetries() async throws {
        let provider = LocationProvider()
        let recorder = WorkoutRouteRecorder(locationManager: provider, initialPlaceRetryDelay: .milliseconds(5))
        recorder.start(at: date, capturesPlaceOnly: true)
        recorder.pause(at: date)
        try await Task.sleep(for: .milliseconds(25))
        #expect(provider.requestLocationCount == 1)
        recorder.resume(at: date)
        provider.authorizationStatus = .denied
        recorder.authorizationChanged(.denied)
        try await Task.sleep(for: .milliseconds(25))
        #expect(provider.requestLocationCount == 2)
        provider.authorizationStatus = .authorizedWhenInUse
        recorder.authorizationChanged(.authorizedWhenInUse)
        _ = recorder.stop()
        try await Task.sleep(for: .milliseconds(25))
        #expect(provider.requestLocationCount == 3)
    }

    @Test("Indoor acquisition stops after five retries when GPS never replies")
    func retryBudget() async throws {
        let provider = LocationProvider()
        let recorder = WorkoutRouteRecorder(locationManager: provider, initialPlaceRetryDelay: .milliseconds(2))
        defer { recorder.cancel() }
        recorder.start(at: date, capturesPlaceOnly: true)
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while provider.requestLocationCount < 6, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        try await Task.sleep(for: .milliseconds(90))
        #expect(provider.requestLocationCount == 6)
    }

    @Test("Workout end waits for one fresh place after rejecting a cached fix")
    func finalPlaceRequest() async throws {
        let end = Date()
        let provider = LocationProvider()
        let recorder = WorkoutRouteRecorder(locationManager: provider)
        func fix(_ timestamp: Date, accuracy: Double) -> CLLocation {
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37, longitude: 127), altitude: 0,
                       horizontalAccuracy: accuracy, verticalAccuracy: -1, timestamp: timestamp)
        }
        provider.location = fix(end.addingTimeInterval(-60), accuracy: 20)
        let laterFix = fix(end.addingTimeInterval(1.1), accuracy: 5)
        let goodFix = fix(end.addingTimeInterval(0.1), accuracy: 5)
        provider.onLocationRequest = {
            Task { @MainActor in
                recorder.receive([laterFix], at: laterFix.timestamp)
                #expect(recorder.capturedPlace == nil)
                recorder.receive([goodFix], at: laterFix.timestamp)
            }
        }
        defer { provider.onLocationRequest = nil }
        let place = try #require(await recorder.capturePlaceAtWorkoutEnd(
            workoutStartedAt: end.addingTimeInterval(-600), endedAt: end
        ))
        #expect(place.latitude == 37 && place.longitude == 127)
        #expect(!recorder.isRecording && recorder.points.isEmpty)
        let existing = await recorder.capturePlaceAtWorkoutEnd(workoutStartedAt: end, endedAt: end)
        #expect(existing == place)
        #expect(provider.requestLocationCount == 1)
    }

    @Test("Ending without permission, after a delay, or without a fix does not block saving")
    func finalPlaceUnavailable() async {
        let end = Date()
        let provider = LocationProvider()
        let recorder = WorkoutRouteRecorder(locationManager: provider)
        let expiredEnd = end.addingTimeInterval(-60)
        #expect(await recorder.capturePlaceAtWorkoutEnd(workoutStartedAt: expiredEnd, endedAt: expiredEnd) == nil)
        provider.authorizationStatus = .denied
        #expect(await recorder.capturePlaceAtWorkoutEnd(workoutStartedAt: end, endedAt: end) == nil)
        #expect(provider.requestLocationCount == 0)
        provider.authorizationStatus = .authorizedWhenInUse
        // A cached measurement taken after this workout cannot stand in for a requested fix.
        provider.location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37, longitude: 127),
                                       altitude: 0, horizontalAccuracy: 5, verticalAccuracy: -1,
                                       timestamp: end.addingTimeInterval(0.25))
        #expect(await recorder.capturePlaceAtWorkoutEnd(
            workoutStartedAt: end, endedAt: end, timeout: .milliseconds(5)
        ) == nil)
        #expect(provider.requestLocationCount == 1 && !recorder.isRecording)
    }

    @Test("Indoor place collection excludes paused movement and denial")
    func indoorPlacePauseAndDenial() {
        let provider = LocationProvider()
        let recorder = WorkoutRouteRecorder(locationManager: provider)
        recorder.start(at: date, capturesPlaceOnly: true)
        recorder.pause(at: date.addingTimeInterval(1))
        recorder.receive([location(2)], at: date.addingTimeInterval(2))
        #expect(recorder.capturedPlace == nil)
        recorder.resume(at: date.addingTimeInterval(3))
        #expect(provider.requestLocationCount == 2)
        #expect(provider.startCount == 0)
        recorder.receive([location(2, longitude: 128)], at: date.addingTimeInterval(4))
        #expect(recorder.capturedPlace == nil)
        recorder.receive([location(4)], at: date.addingTimeInterval(4))
        #expect(recorder.capturedPlace?.longitude == 127)
        recorder.cancel()
        provider.authorizationStatus = .denied
        recorder.start(at: date, capturesPlaceOnly: true)
        recorder.receive([location(1)], at: date.addingTimeInterval(1))
        #expect(recorder.capturedPlace == nil)
        #expect(provider.requestLocationCount == 2)
        recorder.cancel()
    }

    // MARK: - Integration

    @Test(
        "An indoor workout saved without an initial place retains the end-time GPS fix in HealthKit",
        .enabled(if: ProcessInfo.processInfo.environment["DUNE_VERIFY_WATCH_PLACE_HEALTHKIT"] == "1"),
        .timeLimit(.minutes(2))
    )
    func syntheticIndoorWorkoutReadback() async throws {
#if targetEnvironment(simulator)
        let healthStore = HKHealthStore()
        try await healthStore.requestAuthorization(
            toShare: [HKObjectType.workoutType()],
            read: [HKObjectType.workoutType()]
        )
        guard healthStore.authorizationStatus(for: .workoutType()) == .sharingAuthorized else {
            Issue.record("Grant workout write and read access to the Watch test host")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        let start = Date().addingTimeInterval(-90)
        try await builder.beginCollection(at: start)
        let end = Date()
        // Seed the dedicated simulator with simctl location set 37.5665,126.9780.
        let saved = try #require(try await WorkoutManager.finishCardioWorkout(
            builder: builder, mode: .cardio(activityType: .running, isOutdoor: false),
            capturedPlace: nil, startedAt: start, endedAt: end
        ))

        // Query the saved object, not the builder's in-memory return value.
        let readResult: Result<[HKWorkout], any Error>
        do {
            let query = HKSampleQueryDescriptor(
                predicates: [.workout(HKQuery.predicateForObject(with: saved.uuid))],
                sortDescriptors: [], limit: 1
            )
            readResult = .success(try await query.result(for: healthStore))
        } catch {
            readResult = .failure(error)
        }
        try await healthStore.delete(saved)
        let reloaded = try #require(readResult.get().first)
        let place = try #require(WorkoutPlaceMetadata.place(from: reloaded.metadata))
        #expect(abs(place.latitude - 37.5665) < 0.00001)
        #expect(abs(place.longitude - 126.9780) < 0.00001)
        #expect(place.source == .gps)
        #expect(abs(reloaded.endDate.timeIntervalSince(end)) < 0.001)
#else
        Issue.record("Synthetic HealthKit verification is limited to a Watch simulator")
#endif
    }

    @Test("Outdoor route uses continuous high-accuracy updates instead of a place request")
    func outdoorRouteEnergyConfiguration() {
        let provider = LocationProvider()
        let recorder = WorkoutRouteRecorder(locationManager: provider)
        recorder.start(at: date)
        #expect(provider.desiredAccuracy == kCLLocationAccuracyBest)
        #expect(provider.distanceFilter == 10)
        #expect(provider.allowsBackgroundLocationUpdates)
        #expect(provider.startCount == 1)
        #expect(provider.requestLocationCount == 0)
        recorder.cancel()
    }

    @Test("Paused movement is excluded and resumed route starts a distinct segment")
    func pauseBoundaries() {
        let provider = LocationProvider()
        let recorder = WorkoutRouteRecorder(locationManager: provider)
        recorder.start(at: date)
        recorder.receive([location(0), location(1, longitude: 127.00001)], at: date.addingTimeInterval(1))
        recorder.pause(at: date.addingTimeInterval(2))
        recorder.receive([location(3)], at: date.addingTimeInterval(3))
        recorder.resume(at: date.addingTimeInterval(10))
        recorder.receive([location(9), location(10, longitude: 127.00002), location(11, longitude: 127.00003)],
                         at: date.addingTimeInterval(11))
        let points = recorder.stop()
        #expect(points.count == 4)
        #expect(points.map(\.startsNewSegment) == [true, false, true, false])
        #expect(WorkoutRouteSaveJob.segments(points).map(\.count) == [2, 2])
        #expect(provider.startCount == 2)
        recorder.receive([location(12)], at: date.addingTimeInterval(12))
        #expect(recorder.points.count == 4)
    }

    @Test("Stale, inaccurate and non-finite samples are excluded; GPS jumps break lines")
    func sensorValidation() {
        let recorder = WorkoutRouteRecorder(locationManager: LocationProvider())
        recorder.start(at: date)
        recorder.receive([location(-1), location(0), location(1, accuracy: 50),
                          location(2, longitude: .nan), location(3), location(4, longitude: 128)],
                         at: date.addingTimeInterval(4))
        #expect(recorder.points.count == 3)
        #expect(recorder.points.map(\.startsNewSegment) == [true, true, true])
        recorder.receive([location(5)], at: date.addingTimeInterval(30))
        #expect(recorder.points.count == 3)
        recorder.cancel()
        #expect(recorder.points.isEmpty)
        #expect(!recorder.isRecording)
    }

    @Test("Measured altitude honors accuracy, pause, and segment boundaries")
    func measuredElevation() {
        var profile = WatchElevationProfile()
        let start = date
        profile.observe(altitude: 100, at: start, beginsSegment: true)
        profile.observe(altitude: 102, at: start.addingTimeInterval(1), beginsSegment: false)
        #expect(profile.ascentMeters == 0)
        profile.observe(altitude: 104, at: start.addingTimeInterval(2), beginsSegment: false)
        #expect(profile.ascentMeters == 4)
        profile.breakSegment()
        profile.observe(altitude: 120, at: start.addingTimeInterval(10), beginsSegment: true)
        #expect(profile.ascentMeters == 4)
        profile.observe(altitude: nil, at: start.addingTimeInterval(11), beginsSegment: false)
        #expect(profile.currentAltitude == nil)
        profile.observe(altitude: 130, at: start.addingTimeInterval(12), beginsSegment: true)
        #expect(profile.ascentMeters == 4)
    }

    @Test("Outdoor chart keeps elapsed-time gaps instead of packing valid points together")
    func elevationChartGaps() {
        let end = date.addingTimeInterval(1_800)
        var profile = WatchElevationProfile()
        profile.observe(altitude: 100, at: end.addingTimeInterval(-900), beginsSegment: true)
        profile.breakSegment()
        profile.observe(altitude: 104, at: end.addingTimeInterval(-60), beginsSegment: true)
        let buckets = profile.chartBuckets(endingAt: end)
        #expect(buckets.count == 60)
        #expect(buckets[30] == 100)
        #expect(buckets[58] == 104)
        #expect(buckets[31] == nil)
        #expect(buckets[57] == nil)
        #expect(profile.ascentMeters == 0)
        #expect(profile.currentAltitude(at: end) == nil)
    }

    @Test("Outdoor recorder rejects inaccurate altitude while retaining route points")
    func verticalAccuracyGatesAltitude() {
        let recorder = WorkoutRouteRecorder(locationManager: LocationProvider())
        recorder.start(at: date)
        let inaccurate = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37, longitude: 127),
                                    altitude: 110, horizontalAccuracy: 5, verticalAccuracy: 30, timestamp: date)
        recorder.receive([inaccurate], at: date)
        #expect(recorder.points.count == 1)
        #expect(recorder.elevationProfile.samples.isEmpty)
        let valid = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37, longitude: 127.00001),
                               altitude: 100, horizontalAccuracy: 5, verticalAccuracy: 5,
                               timestamp: date.addingTimeInterval(1))
        recorder.receive([valid], at: date.addingTimeInterval(1))
        #expect(recorder.elevationProfile.currentAltitude == 100)
        recorder.cancel()
    }

    @Test("Route memory is bounded and reusing a recorder excludes earlier-session samples")
    func boundAndReuse() {
        let recorder = WorkoutRouteRecorder(locationManager: LocationProvider())
        recorder.start(at: date)
        var maximumPointCount = 0
        for index in 0..<8_100 {
            let time = Double(index)
            recorder.receive([location(time, longitude: 127 + time * 0.000001)], at: date.addingTimeInterval(time))
            maximumPointCount = max(maximumPointCount, recorder.points.count)
        }
        #expect(maximumPointCount <= WorkoutLocationPayload.maxRoutePoints)
        recorder.pause(at: date.addingTimeInterval(8_100))
        _ = recorder.stop()
        recorder.start(at: date.addingTimeInterval(9_000))
        #expect(!recorder.isPaused)
        recorder.receive([location(8_999), location(9_000)], at: date.addingTimeInterval(9_000))
        #expect(recorder.points.count == 1)
        #expect(recorder.points.first?.startsNewSegment == true)
    }

    private final class SegmentWriter: WorkoutRouteSegmentWriting {
        var written: [[WorkoutRoutePoint]] = []
        var cancellationCount = 0
        var shouldFail = false
        var shouldSuspend = false
        var pendingWrite: CheckedContinuation<Void, Never>?
        func write(_ points: [WorkoutRoutePoint]) async throws {
            written.append(points)
            if shouldFail { throw Failure.write }
            // Simulate an HK callback which does not cooperate with Task cancellation.
            if shouldSuspend { await withCheckedContinuation { pendingWrite = $0 } }
        }
        func cancel() { cancellationCount += 1 }
        enum Failure: Error { case write }
    }

    private func routeSegments() throws -> [WorkoutRoutePoint] {
        try (0..<4).map { index in
            try #require(WorkoutRoutePoint(latitude: 37, longitude: 127 + Double(index) * 0.00001,
                                           timestamp: date.addingTimeInterval(Double(index)), startsNewSegment: index == 2))
        }
    }

    private func waitForCompletion(_ job: WorkoutRouteSaveJob) async throws {
        let deadline = Date().addingTimeInterval(1)
        while !job.isFinished, Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
    }

    @Test("Optional route save writes separate segments and completes exactly once")
    func segmentedWrite() async throws {
        let writer = SegmentWriter()
        var completions = 0
        let job = WorkoutRouteSaveJob(points: try routeSegments(), writer: writer) { completions += 1 }
        job.start()
        try await waitForCompletion(job)
        job.cancel()
        #expect(writer.written.map(\.count) == [2, 2])
        #expect(completions == 1)
    }

    @Test("Route failure does not retry and still releases the completed-workout job")
    func failedWrite() async throws {
        let writer = SegmentWriter()
        writer.shouldFail = true
        var completions = 0
        let job = WorkoutRouteSaveJob(points: try routeSegments(), writer: writer) { completions += 1 }
        job.start()
        try await waitForCompletion(job)
        #expect(job.isFinished)
        #expect(writer.written.count == 1)
        #expect(completions == 1)
    }

    @Test("Route timeout cancels the writer without waiting for its async completion")
    func timeout() async throws {
        let writer = SegmentWriter()
        writer.shouldSuspend = true
        defer { writer.pendingWrite?.resume(); writer.pendingWrite = nil }
        var completions = 0
        let job = WorkoutRouteSaveJob(points: try routeSegments(), writer: writer) { completions += 1 }
        job.start(timeout: 0.01)
        try await waitForCompletion(job)
        #expect(job.isFinished)
        #expect(writer.written.count == 1)
        #expect(writer.cancellationCount == 1)
        #expect(completions == 1)
    }

    @Test("Timeout releases the save job even when an injected writer withholds its callback")
    func timeoutReleasesJob() async throws {
        let writer = SegmentWriter()
        writer.shouldSuspend = true
        defer { writer.pendingWrite?.resume(); writer.pendingWrite = nil }
        var completions = 0
        var job: WorkoutRouteSaveJob? = WorkoutRouteSaveJob(points: try routeSegments(), writer: writer) {
            completions += 1
        }
        weak var weakJob = job
        job?.start(timeout: 0.01)
        let deadline = Date().addingTimeInterval(1)
        while completions == 0, Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(completions == 1)
        #expect(writer.pendingWrite != nil)
        job = nil
        await Task.yield()
        #expect(weakJob == nil)
    }

    @Test("HK callback gate handles cancellation before continuation registration")
    func callbackCancelledBeforeRegistration() async {
        let gate = WorkoutRouteCallbackGate()
        gate.cancel()
        var registered = true
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                registered = gate.register(continuation)
            }
            Issue.record("Cancellation should throw")
        } catch {
            #expect(error is CancellationError)
        }
        #expect(!registered)
        // A callback retained by HK may arrive after the deadline. It cannot resume again.
        gate.resolve(.success(()))
        gate.cancel()
    }

    @Test("HK callback gate cancels an active wait exactly once and ignores late callbacks")
    func callbackCancelledWhileWaiting() async {
        let gate = WorkoutRouteCallbackGate()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                #expect(gate.register(continuation))
                gate.cancel()
                gate.resolve(.success(()))
                gate.cancel()
            }
            Issue.record("Cancellation should throw")
        } catch {
            #expect(error is CancellationError)
        }
    }

    @Test("A completed HK callback remains successful when cancellation arrives later")
    func callbackCompletesBeforeCancellation() async throws {
        let gate = WorkoutRouteCallbackGate()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            #expect(gate.register(continuation))
            gate.resolve(.success(()))
            gate.cancel()
            gate.resolve(.failure(SegmentWriter.Failure.write))
        }
    }

}
