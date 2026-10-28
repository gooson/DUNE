import CoreLocation
import Foundation
import Testing
@testable import DUNEWatch

@Suite("StairMachineExitMonitor")
@MainActor
struct StairMachineExitMonitorTests {
    @Test("A denied permission can be granted later without restarting the workout")
    func denialThenGrant() {
        let provider = MockStairExitLocationProvider(status: .denied)
        let monitor = makeMonitor(provider)
        monitor.start()
        #expect(provider.startCount == 0)
        provider.authorizationStatus = .authorizedWhenInUse
        monitor.locationManagerDidChangeAuthorization(CLLocationManager())
        #expect(provider.startCount == 1)
        monitor.stop()
    }

    @Test("New permission is requested and updates start only after authorization")
    func permissionRequest() {
        let provider = MockStairExitLocationProvider(status: .notDetermined)
        let monitor = makeMonitor(provider)
        monitor.start()
        #expect(provider.requestCount == 1)
        #expect(provider.startCount == 0)
        provider.authorizationStatus = .authorizedWhenInUse
        monitor.locationManagerDidChangeAuthorization(CLLocationManager())
        #expect(provider.startCount == 1)
        monitor.stop()
    }

    @Test("Stopping for pause or end prevents a late authorization callback from restarting GPS")
    func stopThenLateGrant() {
        let provider = MockStairExitLocationProvider(status: .notDetermined)
        let monitor = makeMonitor(provider)
        monitor.start()
        monitor.stop()
        provider.authorizationStatus = .authorizedWhenInUse
        monitor.locationManagerDidChangeAuthorization(CLLocationManager())
        #expect(provider.stopCount == 1)
        #expect(provider.startCount == 0)
    }

    @Test("Permission revocation stops GPS and regrant resumes it")
    func revokeThenRegrant() {
        let provider = MockStairExitLocationProvider(status: .authorizedWhenInUse)
        let monitor = makeMonitor(provider)
        monitor.start()
        provider.authorizationStatus = .denied
        monitor.locationManagerDidChangeAuthorization(CLLocationManager())
        #expect(provider.stopCount == 1)
        provider.authorizationStatus = .authorizedAlways
        monitor.locationManagerDidChangeAuthorization(CLLocationManager())
        #expect(provider.startCount == 2)
        monitor.stop()
    }

    @Test("A fresh monitor after resume starts independently of the stopped monitor")
    func pauseAndResume() {
        let provider = MockStairExitLocationProvider(status: .authorizedWhenInUse)
        let paused = makeMonitor(provider)
        paused.start()
        paused.stop()
        let resumed = makeMonitor(provider)
        resumed.start()
        #expect(provider.startCount == 2)
        resumed.stop()
        #expect(provider.stopCount == 2)
    }

    private func makeMonitor(_ provider: MockStairExitLocationProvider) -> StairMachineExitMonitor {
        StairMachineExitMonitor(
            startedAt: Date(), steps: { 0 },
            onExit: { Issue.record("Permission events must never suggest an exit") },
            locationManager: provider
        )
    }
}

@MainActor
private final class MockStairExitLocationProvider: StairExitLocationProviding {
    weak var delegate: (any CLLocationManagerDelegate)?
    var authorizationStatus: CLAuthorizationStatus
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var requestCount = 0

    init(status: CLAuthorizationStatus) { authorizationStatus = status }
    func requestWhenInUseAuthorization() { requestCount += 1 }
    func startUpdatingLocation() { startCount += 1 }
    func stopUpdatingLocation() { stopCount += 1 }
}
