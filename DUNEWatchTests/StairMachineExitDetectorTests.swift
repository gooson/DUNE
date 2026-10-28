import CoreLocation
import Foundation
import Testing
@testable import DUNEWatch

@Suite("StairMachineExitDetector")
struct StairMachineExitDetectorTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test("Stationary GPS jitter and rising machine steps never suggest an exit")
    func stationaryMachine() {
        var detector = StairMachineExitDetector(startedAt: start)
        for index in 0...12 {
            let seconds = TimeInterval(index * 20)
            let jitter = index.isMultiple(of: 2) ? 12.0 : -12.0
            #expect(!observe(&detector,
                location: location(meters: jitter, at: seconds, accuracy: 15),
                steps: Double(index * 20), now: start.addingTimeInterval(seconds)
            ))
        }
    }

    @Test("Outdoor GPS acquired after workout start detects a sustained walk")
    func outdoorAcquisition() {
        var detector = StairMachineExitDetector(startedAt: start)
        let samples: [(TimeInterval, Double, Double)] = [
            (150, 0, 200), (170, 40, 215), (190, 80, 230), (210, 120, 245)
        ]
        #expect(samples.map { sample in
            detector.observe(
                location: location(meters: sample.1, at: sample.0),
                steps: sample.2, now: start.addingTimeInterval(sample.0)
            )
        } == [false, false, false, true])
    }

    @Test("No GPS observations never produce a recommendation")
    func deniedLocation() {
        var detector = StairMachineExitDetector(startedAt: start)
        for index in 0...12 {
            let seconds = TimeInterval(150 + index * 20)
            #expect(!observe(&detector,
                location: location(meters: Double(index * 40), at: seconds, accuracy: -1),
                steps: Double(index * 20), now: start.addingTimeInterval(seconds)
            ))
        }
    }

    @Test("Invalid accuracy, coordinates, and sample age cannot seed the candidate")
    func invalidLocations() {
        let invalid: [CLLocation] = [
            location(meters: 0, at: 150, accuracy: 0),
            location(meters: 0, at: 150, accuracy: -1),
            location(meters: 0, at: 150, accuracy: 20.1),
            location(meters: 0, at: 150, accuracy: .nan),
            location(meters: 0, at: 150, latitude: .nan),
            location(meters: 0, at: 150, latitude: 91),
            location(meters: 0, at: 129), // 21 seconds old
            location(meters: 0, at: 156)  // 6 seconds in the future
        ]
        for sample in invalid {
            var detector = StairMachineExitDetector(startedAt: start)
            #expect(!observe(&detector, location: sample, steps: 0,
                                      now: start.addingTimeInterval(150)))
            #expect(!observe(&detector, location: location(meters: 40, at: 170), steps: 15,
                                      now: start.addingTimeInterval(170)))
            #expect(!observe(&detector, location: location(meters: 80, at: 190), steps: 30,
                                      now: start.addingTimeInterval(190)))
            #expect(!observe(&detector, location: location(meters: 120, at: 210), steps: 45,
                                      now: start.addingTimeInterval(210)))
        }
    }

    @Test("Invalid step counts are ignored without seeding a candidate")
    func invalidSteps() {
        for steps in [-1.0, .nan, .infinity, 200_001] {
            var detector = StairMachineExitDetector(startedAt: start)
            #expect(!observe(&detector, location: location(meters: 0, at: 150), steps: steps,
                                      now: start.addingTimeInterval(150)))
            #expect(!observe(&detector, location: location(meters: 40, at: 170), steps: 15,
                                      now: start.addingTimeInterval(170)))
            #expect(!observe(&detector, location: location(meters: 80, at: 190), steps: 30,
                                      now: start.addingTimeInterval(190)))
            #expect(!observe(&detector, location: location(meters: 120, at: 210), steps: 45,
                                      now: start.addingTimeInterval(210)))
        }
    }

    @Test("GPS jumps and vehicle speed reset the candidate")
    func impossibleMovement() {
        var detector = StairMachineExitDetector(startedAt: start)
        #expect(!observe(&detector, meters: 0, seconds: 150, steps: 0))
        #expect(!observe(&detector, meters: 40, seconds: 170, steps: 15))
        #expect(!observe(&detector, meters: 500, seconds: 190, steps: 30))
        #expect(!observe(&detector, meters: 540, seconds: 210, steps: 45))
        #expect(!observe(&detector, meters: 580, seconds: 230, steps: 60))
        #expect(observe(&detector, meters: 620, seconds: 250, steps: 75))
    }

    @Test("Gaps and step counter rollback rebase the displacement and steps")
    func gapsAndRollback() {
        var detector = StairMachineExitDetector(startedAt: start)
        #expect(!observe(&detector, meters: 0, seconds: 150, steps: 0))
        #expect(!observe(&detector, meters: 40, seconds: 170, steps: 15))
        #expect(!observe(&detector, meters: 80, seconds: 210, steps: 30)) // 40-second gap
        #expect(!observe(&detector, meters: 120, seconds: 230, steps: 45))
        #expect(!observe(&detector, meters: 160, seconds: 250, steps: 10)) // rollback
        #expect(!observe(&detector, meters: 200, seconds: 270, steps: 25))
        #expect(!observe(&detector, meters: 240, seconds: 290, steps: 40))
        #expect(observe(&detector, meters: 280, seconds: 310, steps: 55))
    }

    @Test("Out-of-order location and wall-clock times do not advance the candidate")
    func outOfOrder() {
        var detector = StairMachineExitDetector(startedAt: start)
        #expect(!observe(&detector, meters: 0, seconds: 150, steps: 0))
        #expect(!observe(&detector, location: location(meters: 40, at: 170), steps: 15,
                                  now: start.addingTimeInterval(175)))
        #expect(!observe(&detector, meters: 80, seconds: 170, steps: 30))
        #expect(!observe(&detector, meters: 80, seconds: 160, steps: 30))
        #expect(!observe(&detector, location: location(meters: 58, at: 179), steps: 30,
                                  now: start.addingTimeInterval(174)))
        #expect(!observe(&detector, meters: 80, seconds: 190, steps: 30))
        #expect(observe(&detector, meters: 120, seconds: 210, steps: 45))
    }

    @Test("Warmup, sample count, duration, distance, and steps are all required")
    func boundaries() {
        var detector = StairMachineExitDetector(startedAt: start)
        #expect(!observe(&detector, meters: 0, seconds: 20, steps: 0))
        #expect(!observe(&detector, meters: 40, seconds: 40, steps: 15))
        #expect(!observe(&detector, meters: 80, seconds: 60, steps: 30))
        #expect(!observe(&detector, meters: 120, seconds: 80, steps: 39)) // warmup and steps
        #expect(!observe(&detector, meters: 120, seconds: 100, steps: 40)) // warmup
        #expect(observe(&detector, meters: 120, seconds: 120, steps: 40))

        var tooFew = StairMachineExitDetector(startedAt: start)
        #expect(!observe(&tooFew, meters: 0, seconds: 150, steps: 0))
        #expect(!observe(&tooFew, meters: 60, seconds: 180, steps: 25))
        #expect(!observe(&tooFew, meters: 120, seconds: 210, steps: 50))

        var tooShort = StairMachineExitDetector(startedAt: start)
        for (seconds, meters, steps) in [(150.0, 0.0, 0.0), (170, 40, 15),
                                         (190, 80, 30), (209, 119, 45)] {
            #expect(!observe(&tooShort, meters: meters, seconds: seconds, steps: steps))
        }

        var tooNear = StairMachineExitDetector(startedAt: start)
        for (seconds, meters, steps) in [(150.0, 0.0, 0.0), (170, 33, 15),
                                         (190, 66, 30), (210, 99, 45)] {
            #expect(!observe(&tooNear, meters: meters, seconds: seconds, steps: steps))
        }
    }

    @Test("A dismissed suggestion cannot repeat, while a new session is independent")
    func dismissalAndFreshSession() {
        var first = StairMachineExitDetector(startedAt: start)
        #expect(!observe(&first, meters: 0, seconds: 150, steps: 0))
        #expect(!observe(&first, meters: 40, seconds: 170, steps: 15))
        #expect(!observe(&first, meters: 80, seconds: 190, steps: 30))
        #expect(observe(&first, meters: 120, seconds: 210, steps: 45))
        #expect(!observe(&first, meters: 140, seconds: 220, steps: 50))
        first.dismiss()
        #expect(!observe(&first, meters: 160, seconds: 230, steps: 60))

        var second = StairMachineExitDetector(startedAt: start)
        #expect(!observe(&second, meters: 0, seconds: 150, steps: 0))
        #expect(!observe(&second, meters: 40, seconds: 170, steps: 15))
        #expect(!observe(&second, meters: 80, seconds: 190, steps: 30))
        #expect(observe(&second, meters: 120, seconds: 210, steps: 45))
    }

    private func observe(
        _ detector: inout StairMachineExitDetector,
        meters: Double, seconds: TimeInterval, steps: Double
    ) -> Bool {
        detector.observe(location: location(meters: meters, at: seconds),
                         steps: steps, now: start.addingTimeInterval(seconds))
    }

    // Swift Testing captures member-call receivers immutably. Pass the mutation explicitly.
    private func observe(
        _ detector: inout StairMachineExitDetector,
        location: CLLocation, steps: Double, now: Date
    ) -> Bool {
        detector.observe(location: location, steps: steps, now: now)
    }

    private func location(
        meters: Double, at seconds: TimeInterval, accuracy: CLLocationAccuracy = 5,
        latitude: CLLocationDegrees = 0
    ) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: meters / 111_195),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 5,
            timestamp: start.addingTimeInterval(seconds)
        )
    }
}
