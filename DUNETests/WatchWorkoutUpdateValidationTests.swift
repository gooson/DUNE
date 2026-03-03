import Foundation
import Testing
@testable import DUNE

@Suite("Watch Workout Update Validation")
struct WatchWorkoutUpdateValidationTests {
    @Test("validated filters out invalid set and heart rate samples")
    func validatedFiltersOutInvalidSamples() {
        let update = WatchWorkoutUpdate(
            exerciseID: "squat",
            exerciseName: "Back Squat",
            completedSets: [
                WatchSetData(setNumber: 1, weight: 100, reps: 5, duration: nil, restDuration: nil, isCompleted: true),
                WatchSetData(setNumber: 2, weight: 999, reps: 5, duration: nil, restDuration: nil, isCompleted: true),
                WatchSetData(setNumber: 3, weight: 80, reps: 5000, duration: nil, restDuration: nil, isCompleted: true),
            ],
            startTime: Date(timeIntervalSince1970: 1_738_000_000),
            endTime: Date(timeIntervalSince1970: 1_738_000_300),
            heartRateSamples: [
                WatchHeartRateSample(bpm: 120, timestamp: Date(timeIntervalSince1970: 1_738_000_100)),
                WatchHeartRateSample(bpm: 10, timestamp: Date(timeIntervalSince1970: 1_738_000_110)),
            ]
        )

        let validated = update.validated()

        #expect(validated.completedSets.count == 1)
        #expect(validated.completedSets[0].setNumber == 1)
        #expect(validated.heartRateSamples.count == 1)
        #expect(validated.heartRateSamples[0].bpm == 120)
    }

    @Test("validated preserves legal boundary values")
    func validatedPreservesBoundaryValues() {
        let update = WatchWorkoutUpdate(
            exerciseID: "run",
            exerciseName: "Running",
            completedSets: [
                WatchSetData(setNumber: 1, weight: 0, reps: 0, duration: 0, restDuration: nil, isCompleted: true),
                WatchSetData(setNumber: 2, weight: 500, reps: 1000, duration: 28_800, restDuration: nil, isCompleted: true),
            ],
            startTime: Date(timeIntervalSince1970: 1_738_100_000),
            endTime: nil,
            heartRateSamples: [
                WatchHeartRateSample(bpm: 20, timestamp: Date(timeIntervalSince1970: 1_738_100_100)),
                WatchHeartRateSample(bpm: 300, timestamp: Date(timeIntervalSince1970: 1_738_100_110)),
            ]
        )

        let validated = update.validated()

        #expect(validated.completedSets.count == 2)
        #expect(validated.heartRateSamples.count == 2)
    }
}
