import CoreLocation
import Foundation
import Testing
@testable import DUNEWatch

@Suite("Watch workout routes")
@MainActor
struct WorkoutRouteRecorderTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private final class LocationProvider: WorkoutRouteLocationProviding {
        var delegate: CLLocationManagerDelegate?
        var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
        var requestCount = 0
        var startCount = 0
        var stopCount = 0
        func requestWhenInUseAuthorization() { requestCount += 1 }
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
