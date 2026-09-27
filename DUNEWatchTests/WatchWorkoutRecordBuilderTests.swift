import Foundation
import SwiftData
import Testing
@testable import DUNEWatch

@Suite("WatchWorkoutRecordBuilder")
@MainActor
struct WatchWorkoutRecordBuilderTests {
    private let startDate = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeRecord(
        duration: TimeInterval = 600,
        restDuration: TimeInterval? = 90,
        effort: Int = 3,
        startDate: Date? = nil,
        history: [ExerciseRecord] = []
    ) -> ExerciseRecord {
        let recordStartDate = startDate ?? self.startDate
        return WatchWorkoutRecordBuilder.makeRecord(
            exerciseName: "Squat",
            exerciseDefinitionID: "barbell-squat",
            sets: [CompletedSetData(
                setNumber: 1, weight: 60, reps: 10, duration: 45,
                completedAt: recordStartDate.addingTimeInterval(45), restDuration: restDuration, rpe: 10,
                plannedReps: 12, rpeSourceRaw: "estimated"
            )],
            startDate: recordStartDate,
            duration: duration,
            calories: 80,
            calorieSource: .met,
            effort: effort,
            inputType: .setsRepsWeight,
            history: history,
            plannedSetCount: 3,
            healthKitWorkoutID: UUID().uuidString
        )
    }

    @Test("Chosen effort survives conflicting set RPE in local and transmitted records")
    func chosenEffortWins() {
        let record = makeRecord()
        let update = WatchWorkoutRecordBuilder.makeUpdate(from: record)

        #expect(record.rpe == 3)
        #expect(update.rpe == 3)
        #expect(record.sets?.first?.rpe == 10)
        #expect(update.completedSets.first?.rpe == 10)
        #expect(record.effortSourceRaw == "user")
        #expect(update.effortSourceRaw == "user")
        #expect(record.autoIntensityRaw == 0.3)
    }

    @Test("Recent strength history contributes to automatic intensity while chosen effort stays final")
    func strengthHistoryAndFinalEffort() {
        let earlier = makeRecord(startDate: startDate.addingTimeInterval(-2 * 24 * 60 * 60))
        let recent = makeRecord(startDate: startDate.addingTimeInterval(-24 * 60 * 60))
        let record = makeRecord(effort: 9, history: [earlier, recent])

        #expect(record.rpe == 9)
        let rawScore = record.autoIntensityRaw ?? -1
        #expect(rawScore > 0.8 && rawScore < 0.9)
    }

    @Test("Planned warmup type survives local record and wire update")
    func warmupTypeSurvives() {
        let record = WatchWorkoutRecordBuilder.makeRecord(
            exerciseName: "Squat",
            exerciseDefinitionID: "squat",
            sets: [CompletedSetData(
                setNumber: 1, weight: 20, reps: 10, duration: nil,
                completedAt: startDate, setTypeRaw: SetType.warmup.rawValue
            )],
            startDate: startDate,
            duration: 60,
            calories: nil,
            calorieSource: .manual,
            effort: 5,
            inputType: .setsRepsWeight,
            history: [],
            plannedSetCount: 2,
            healthKitWorkoutID: nil
        )
        #expect(record.sets?.first?.setType == .warmup)
        #expect(WatchWorkoutRecordBuilder.makeUpdate(from: record).completedSets.first?.setTypeRaw == SetType.warmup.rawValue)
    }

    @Test("Rest durations survive record mapping and wire encoding", arguments: [nil, 0, 90, 120] as [Double?])
    func restDurationRoundTrip(restDuration: Double?) throws {
        let record = makeRecord(restDuration: restDuration)
        let update = WatchWorkoutRecordBuilder.makeUpdate(from: record)
        let decoded = try JSONDecoder().decode(WatchWorkoutUpdate.self, from: JSONEncoder().encode(update))

        #expect(record.sets?.first?.restDuration == restDuration)
        #expect(decoded.completedSets.first?.restDuration == restDuration)
        #expect(decoded.completedSets.first?.weight == 60)
        #expect(decoded.completedSets.first?.reps == 10)
        #expect(decoded.healthKitWorkoutID == record.healthKitWorkoutID)
        #expect(decoded.calories == 80)
        #expect(decoded.calorieSourceRaw == CalorieSource.met.rawValue)
        #expect(decoded.plannedSetCount == 3)
        #expect(decoded.effortSourceRaw == "user")
        #expect(decoded.completedSets.first?.plannedReps == 12)
        #expect(decoded.completedSets.first?.rpeSourceRaw == "estimated")
        #expect(decoded.completedSets.first?.setTypeRaw == SetType.working.rawValue)
    }

    @Test("Per-exercise wire durations sum to the session duration", arguments: [1, 3])
    func allocatedDurationIsTransmitted(exerciseCount: Int) throws {
        let sessionDuration: TimeInterval = 1800
        let records = (0..<exerciseCount).map { _ in
            makeRecord(duration: sessionDuration / Double(exerciseCount))
        }
        var receivedTotal: TimeInterval = 0
        for record in records {
            let update = WatchWorkoutRecordBuilder.makeUpdate(from: record)
            let decoded = try JSONDecoder().decode(WatchWorkoutUpdate.self, from: JSONEncoder().encode(update))
            // The iPhone receiver derives duration from these timestamps.
            let duration = try #require(decoded.endTime).timeIntervalSince(decoded.startTime)
            #expect(duration == record.duration)
            receivedTotal += duration
        }
        #expect(receivedTotal == sessionDuration)
    }

    // MARK: - Persistence Integration

    @Test("A fresh context rebuilds the same payload for later bulk sync")
    func persistedRecordRetainsSummaryValues() throws {
        let container = try ModelContainer(
            for: ExerciseRecord.self, WorkoutSet.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
        let context = ModelContext(container)
        let record = makeRecord()
        context.insert(record)
        try context.save()
        let immediate = WatchWorkoutRecordBuilder.makeUpdate(from: record)

        let restoredContext = ModelContext(container)
        let restored = try #require(restoredContext.fetch(FetchDescriptor<ExerciseRecord>()).first)
        let bulk = WatchWorkoutRecordBuilder.makeUpdate(from: restored)
        #expect(try restoredContext.fetchCount(FetchDescriptor<WorkoutSet>()) == 1)
        #expect(bulk.rpe == 3)
        #expect(restored.autoIntensityRaw == 0.3)
        #expect(bulk.completedSets.first?.restDuration == 90)
        #expect(bulk.completedSets.first?.plannedReps == 12)
        #expect(bulk.completedSets.first?.rpeSourceRaw == "estimated")
        #expect(bulk.plannedSetCount == 3)
        #expect(bulk.effortSourceRaw == "user")
        #expect(bulk.startTime == immediate.startTime)
        #expect(bulk.endTime == immediate.endTime)
        #expect(bulk.healthKitWorkoutID == immediate.healthKitWorkoutID)
        #expect(bulk.calories == immediate.calories)
    }
}
