import Foundation
import Testing
@testable import DUNE

@Suite("Watch Workout Update Validation")
struct WatchWorkoutUpdateValidationTests {
    private func makeBaseUpdate(
        completedSets: [WatchSetData] = [
            WatchSetData(setNumber: 1, weight: 100, reps: 5, duration: 60, restDuration: 90, isCompleted: true)
        ],
        heartRateSamples: [WatchHeartRateSample] = [
            WatchHeartRateSample(bpm: 120, timestamp: Date(timeIntervalSince1970: 1_738_000_100))
        ],
        rpe: Int? = nil
    ) -> WatchWorkoutUpdate {
        WatchWorkoutUpdate(
            exerciseID: "squat",
            exerciseName: "Back Squat",
            completedSets: completedSets,
            startTime: Date(timeIntervalSince1970: 1_738_000_000),
            endTime: Date(timeIntervalSince1970: 1_738_000_300),
            heartRateSamples: heartRateSamples,
            rpe: rpe
        )
    }

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
        let update = makeBaseUpdate(
            completedSets: [
                WatchSetData(setNumber: 1, weight: 0, reps: 0, duration: 0, restDuration: nil, isCompleted: true),
                WatchSetData(setNumber: 2, weight: 500, reps: 1000, duration: 28_800, restDuration: nil, isCompleted: true),
            ],
            heartRateSamples: [
                WatchHeartRateSample(bpm: 20, timestamp: Date(timeIntervalSince1970: 1_738_100_100)),
                WatchHeartRateSample(bpm: 300, timestamp: Date(timeIntervalSince1970: 1_738_100_110)),
            ]
        )

        let validated = update.validated()

        #expect(validated.completedSets.count == 2)
        #expect(validated.heartRateSamples.count == 2)
    }

    @Test("validated clears out-of-range RPE and preserves boundary values")
    func validatedRPEBounds() {
        let tooLow = makeBaseUpdate(rpe: 0).validated()
        let tooHigh = makeBaseUpdate(rpe: 11).validated()
        let lowerBound = makeBaseUpdate(rpe: 1).validated()
        let upperBound = makeBaseUpdate(rpe: 10).validated()

        #expect(tooLow.rpe == nil)
        #expect(tooHigh.rpe == nil)
        #expect(lowerBound.rpe == 1)
        #expect(upperBound.rpe == 10)
    }

    @Test("validated rejects invalid duration and restDuration values")
    func validatedRejectsInvalidDurationAndRest() {
        let update = makeBaseUpdate(
            completedSets: [
                WatchSetData(setNumber: 1, weight: 80, reps: 8, duration: -1, restDuration: 60, isCompleted: true),
                WatchSetData(setNumber: 2, weight: 80, reps: 8, duration: 30, restDuration: -1, isCompleted: true),
                WatchSetData(setNumber: 3, weight: 80, reps: 8, duration: 30, restDuration: 3601, isCompleted: true),
                WatchSetData(setNumber: 4, weight: 80, reps: 8, duration: 28_800, restDuration: 3600, isCompleted: true),
            ]
        )

        let validated = update.validated()

        #expect(validated.completedSets.count == 1)
        #expect(validated.completedSets[0].setNumber == 4)
    }

    @Test("validated heart-rate boundaries keep 20...300 and filter outliers")
    func validatedHeartRateBoundaries() {
        let update = makeBaseUpdate(
            heartRateSamples: [
                WatchHeartRateSample(bpm: 19.9, timestamp: Date(timeIntervalSince1970: 1_738_200_100)),
                WatchHeartRateSample(bpm: 20, timestamp: Date(timeIntervalSince1970: 1_738_200_110)),
                WatchHeartRateSample(bpm: 300, timestamp: Date(timeIntervalSince1970: 1_738_200_120)),
                WatchHeartRateSample(bpm: 300.1, timestamp: Date(timeIntervalSince1970: 1_738_200_130)),
            ]
        )

        let validated = update.validated()
        #expect(validated.heartRateSamples.map(\.bpm) == [20, 300])
    }
}
