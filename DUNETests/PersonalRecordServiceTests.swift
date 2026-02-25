import Foundation
import Testing
@testable import DUNE

@Suite("PersonalRecordService")
struct PersonalRecordServiceTests {

    private func makeWorkout(
        distance: Double? = nil,
        calories: Double? = nil,
        duration: TimeInterval = 1800,
        pace: Double? = nil,
        elevation: Double? = nil,
        activityType: WorkoutActivityType = .running
    ) -> WorkoutSummary {
        WorkoutSummary(
            id: UUID().uuidString,
            type: activityType.typeName,
            activityType: activityType,
            duration: duration,
            calories: calories,
            distance: distance,
            date: Date(),
            averagePace: pace,
            elevationAscended: elevation
        )
    }

    // MARK: - New Record Detection

    @Test("Detects fastest pace as new record when no existing records")
    func detectsFastestPaceNew() {
        let workout = makeWorkout(distance: 5000, pace: 300) // 5min/km
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: [:])
        #expect(result.contains(.fastestPace))
    }

    @Test("Detects fastest pace when beating existing record")
    func detectsFastestPaceBetter() {
        let existing: [PersonalRecordType: PersonalRecord] = [
            .fastestPace: PersonalRecord(type: .fastestPace, value: 350, date: Date(), workoutID: "old"),
        ]
        let workout = makeWorkout(distance: 5000, pace: 300)
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: existing)
        #expect(result.contains(.fastestPace))
    }

    @Test("Does not detect pace when slower than existing record")
    func doesNotDetectSlowerPace() {
        let existing: [PersonalRecordType: PersonalRecord] = [
            .fastestPace: PersonalRecord(type: .fastestPace, value: 280, date: Date(), workoutID: "old"),
        ]
        let workout = makeWorkout(distance: 5000, pace: 300)
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: existing)
        #expect(!result.contains(.fastestPace))
    }

    @Test("Detects longest distance")
    func detectsLongestDistance() {
        let workout = makeWorkout(distance: 15000)
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: [:])
        #expect(result.contains(.longestDistance))
    }

    @Test("Detects highest calories")
    func detectsHighestCalories() {
        let workout = makeWorkout(calories: 500)
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: [:])
        #expect(result.contains(.highestCalories))
    }

    @Test("Detects longest duration")
    func detectsLongestDuration() {
        let workout = makeWorkout(duration: 7200) // 2 hours
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: [:])
        #expect(result.contains(.longestDuration))
    }

    @Test("Detects highest elevation")
    func detectsHighestElevation() {
        let workout = makeWorkout(elevation: 500)
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: [:])
        #expect(result.contains(.highestElevation))
    }

    @Test("Ignores invalid pace values")
    func ignoresInvalidPace() {
        let workout = makeWorkout(pace: -1)
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: [:])
        #expect(!result.contains(.fastestPace))
    }

    @Test("Ignores NaN calories")
    func ignoresNaNCalories() {
        let workout = makeWorkout(calories: Double.nan)
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: [:])
        #expect(!result.contains(.highestCalories))
    }

    @Test("Ignores zero distance")
    func ignoresZeroDistance() {
        let workout = makeWorkout(distance: 0)
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: [:])
        #expect(!result.contains(.longestDistance))
    }

    @Test("Ignores excessively high calories (> 10000)")
    func ignoresExcessiveCalories() {
        let workout = makeWorkout(calories: 15000)
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: [:])
        #expect(!result.contains(.highestCalories))
    }

    // MARK: - Build Records

    @Test("Builds records with correct values")
    func buildsRecordsCorrectly() {
        let workout = makeWorkout(distance: 10000, calories: 500, duration: 3600, pace: 360, elevation: 200)
        let types: [PersonalRecordType] = [.longestDistance, .highestCalories]
        let records = PersonalRecordService.buildRecords(from: workout, types: types)

        #expect(records.count == 2)
        #expect(records[.longestDistance]?.value == 10000)
        #expect(records[.highestCalories]?.value == 500)
    }

    @Test("Does not detect pace for non-distance-based activity")
    func noPaceForStrength() {
        let workout = makeWorkout(pace: 300, activityType: .traditionalStrengthTraining)
        let result = PersonalRecordService.detectNewRecords(workout: workout, existingRecords: [:])
        #expect(!result.contains(.fastestPace))
    }
}
