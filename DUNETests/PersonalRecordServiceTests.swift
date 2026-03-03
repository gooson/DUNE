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
        activityType: WorkoutActivityType = .running,
        stepCount: Double? = nil
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
            elevationAscended: elevation,
            stepCount: stepCount
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

    // MARK: - Milestones

    @Test("Milestone: running uses fixed distance tiers")
    func runningMilestoneTier() {
        let workout = makeWorkout(distance: 16_000, activityType: .running)
        let milestone = workout.activityType.milestoneAchievement(
            distanceMeters: workout.distance,
            stepCount: workout.stepCount,
            durationSeconds: workout.duration
        )
        #expect(milestone?.metric == .distanceMeters)
        #expect(milestone?.tier == 3)
        #expect(milestone?.threshold == 15_000)
    }

    @Test("Milestone: walking prefers step-count tiers")
    func walkingStepMilestoneTier() {
        let workout = makeWorkout(
            distance: 5_000,
            duration: 2_400,
            activityType: .walking,
            stepCount: 15_500
        )
        let milestone = workout.activityType.milestoneAchievement(
            distanceMeters: workout.distance,
            stepCount: workout.stepCount,
            durationSeconds: workout.duration
        )
        #expect(milestone?.metric == .stepCount)
        #expect(milestone?.tier == 2)
        #expect(milestone?.threshold == 15_000)
    }
}

@Suite("WorkoutRewardStore")
struct WorkoutRewardStoreTests {

    private func makeWorkout(
        id: String = UUID().uuidString,
        activityType: WorkoutActivityType = .running,
        distance: Double? = nil,
        duration: TimeInterval = 1800,
        stepCount: Double? = nil
    ) -> WorkoutSummary {
        WorkoutSummary(
            id: id,
            type: activityType.typeName,
            activityType: activityType,
            duration: duration,
            calories: 400,
            distance: distance,
            date: Date(),
            averagePace: 320,
            stepCount: stepCount
        )
    }

    private func makeRewardStore() -> PersonalRecordStore {
        let suiteName = "WorkoutRewardStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return PersonalRecordStore(defaults: defaults)
    }

    @Test("Reward representative prioritizes level-up over other events")
    func representativePriorityLevelUp() {
        let store = makeRewardStore()

        let firstWorkout = makeWorkout(id: "w1", distance: 5_400, duration: 3_000)
        _ = store.evaluateReward(for: firstWorkout, newPRTypes: [.longestDistance])

        let secondWorkout = makeWorkout(id: "w2", distance: 10_800, duration: 4_200)
        let outcome = store.evaluateReward(
            for: secondWorkout,
            newPRTypes: [.longestDistance, .longestDuration]
        )

        #expect(outcome.representativeEvent?.kind == .levelUp)
        #expect(outcome.summary.level >= 2)
    }

    @Test("Reward evaluation is idempotent for duplicate workout callbacks")
    func rewardEvaluationIdempotent() {
        let store = makeRewardStore()
        let workout = makeWorkout(id: "dup", distance: 6_200, duration: 2_700)

        let first = store.evaluateReward(for: workout, newPRTypes: [.longestDistance])
        let second = store.evaluateReward(for: workout, newPRTypes: [.longestDistance])

        #expect(!first.events.isEmpty)
        #expect(second.events.isEmpty)
        #expect(second.representativeEvent == nil)
    }
}
