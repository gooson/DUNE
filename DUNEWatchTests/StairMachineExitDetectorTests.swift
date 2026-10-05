import Foundation
import Testing
@testable import DUNEWatch

@Suite("StairMachineExitDetector")
struct StairMachineExitDetectorTests {
    @Test("Suggests ending after sustained walking following stationary machine use")
    func suggestsAfterWalkingTransition() {
        let detector = StairMachineExitDetector()
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(!detector.observe(at: start, elapsed: 0, distance: 0, steps: 0))
        #expect(!detector.observe(at: start.addingTimeInterval(90), elapsed: 90, distance: 0, steps: 120))
        #expect(!detector.observe(at: start.addingTimeInterval(100), elapsed: 100, distance: 7, steps: 125))
        #expect(!detector.observe(at: start.addingTimeInterval(119), elapsed: 119, distance: 29, steps: 141))
        #expect(detector.observe(at: start.addingTimeInterval(120), elapsed: 120, distance: 32, steps: 142))
        #expect(!detector.observe(at: start.addingTimeInterval(150), elapsed: 150, distance: 70, steps: 185))
    }

    @Test("Avoids suggesting when the machine already records walking distance")
    func earlyDistanceDisqualifies() {
        let detector = StairMachineExitDetector()
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(!detector.observe(at: start.addingTimeInterval(60), elapsed: 60, distance: 8, steps: 50))
        #expect(!detector.observe(at: start.addingTimeInterval(90), elapsed: 90, distance: 8, steps: 80))
        #expect(!detector.observe(at: start.addingTimeInterval(150), elapsed: 150, distance: 90, steps: 180))
    }

    @Test("Distance alone can confirm walking when step samples are unavailable")
    func distanceFallback() {
        let detector = StairMachineExitDetector()
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(!detector.observe(at: start.addingTimeInterval(90), elapsed: 90, distance: 0, steps: 0))
        #expect(!detector.observe(at: start.addingTimeInterval(100), elapsed: 100, distance: 7, steps: 0))
        #expect(!detector.observe(at: start.addingTimeInterval(139), elapsed: 139, distance: 59, steps: 0))
        #expect(detector.observe(at: start.addingTimeInterval(140), elapsed: 140, distance: 60, steps: 0))
    }

    @Test("Dismissing the suggestion suppresses it for the current workout")
    func dismissalSuppressesSuggestion() {
        let detector = StairMachineExitDetector()
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(!detector.observe(at: start.addingTimeInterval(90), elapsed: 90, distance: 0, steps: 100))
        #expect(!detector.observe(at: start.addingTimeInterval(100), elapsed: 100, distance: 7, steps: 105))
        detector.dismissSuggestion()
        #expect(!detector.observe(at: start.addingTimeInterval(140), elapsed: 140, distance: 70, steps: 160))
    }

    @Test("Rejects invalid HealthKit values")
    func invalidMetricsDoNotTrigger() {
        let detector = StairMachineExitDetector()
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(!detector.observe(at: start.addingTimeInterval(90), elapsed: 90, distance: .nan, steps: 0))
        #expect(!detector.observe(at: start.addingTimeInterval(90), elapsed: 90, distance: 0, steps: 0))
        #expect(!detector.observe(at: start.addingTimeInterval(100), elapsed: 100, distance: 7, steps: 0))
        #expect(!detector.observe(at: start.addingTimeInterval(140), elapsed: 140, distance: .infinity, steps: 40))
    }
}
