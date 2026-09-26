import Foundation
import Testing
@testable import DUNE

@Suite("ExerciseRecord intensity finalization")
struct ExerciseRecordIntensityTests {
    private func record(rpe: Double = 8, source: String? = "user") -> ExerciseRecord {
        let record = ExerciseRecord(exerciseDefinitionID: "bench")
        record.sets = [WorkoutSet(weight: 60, reps: 10, isCompleted: true, rpe: rpe, plannedReps: 10, rpeSourceRaw: source)]
        return record
    }

    @Test("Set effort is applied before auto intensity, then user override recomputes it")
    func finalEffortRecomputesIntensity() {
        let current = record()
        current.applySetBasedRPE()
        #expect(current.rpe == 5)
        #expect(current.effortSourceRaw == "setAverage")
        current.refreshAutoIntensity(exerciseType: .setsRepsWeight, history: [])
        #expect(current.autoIntensityRaw == 0.5)
        current.applyUserEffort(9)
        current.refreshAutoIntensity(exerciseType: .setsRepsWeight, history: [current])
        #expect(current.autoIntensityRaw == 0.9)
        #expect(current.effortSourceRaw == "user")
        current.applySetBasedRPE()
        #expect(current.rpe == 9)
    }

    @Test("Current record never contaminates its own history after insertion")
    func excludesSelf() {
        let current = record()
        let previous = record(rpe: 7)
        previous.date = current.date.addingTimeInterval(-86400)
        current.applySetBasedRPE()
        let before = current.refreshAutoIntensity(exerciseType: .setsRepsWeight, history: [previous])?.rawScore
        let after = current.refreshAutoIntensity(exerciseType: .setsRepsWeight, history: [previous, current])?.rawScore
        #expect(before == after)
    }

    @Test("Estimated RPE and incomplete sets do not become confirmed session effort")
    func excludesUnconfirmed() {
        let current = record(source: "estimated")
        current.sets?.append(WorkoutSet(isCompleted: false, rpe: 10, rpeSourceRaw: "user"))
        current.applySetBasedRPE()
        #expect(current.rpe == nil)
        #expect(current.effortSourceRaw == nil)
    }

    @Test("Legacy session ratings survive recomputation and invalid user input")
    func preservesLegacyEffort() {
        let current = record()
        current.rpe = 3
        current.applySetBasedRPE()
        current.applyUserEffort(11)
        #expect(current.rpe == 3)
        #expect(current.effortSourceRaw == nil)
    }

    @Test("Warmups do not contribute to derived effort")
    func excludesWarmup() {
        let current = record()
        current.sets?.append(WorkoutSet(setType: .warmup, isCompleted: true, rpe: 10, rpeSourceRaw: "user"))
        current.applySetBasedRPE()
        #expect(current.rpe == 5)
    }
}
