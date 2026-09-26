import Foundation
import Testing
@testable import DUNE

@Suite("Watch workout metadata")
struct WatchConnectivityMetadataTests {
    @Test("Legacy set and procedure payloads decode with unknown metadata")
    func legacyPayloadsDecode() throws {
        let legacySet = Data(#"{"setNumber":1,"weight":80,"reps":5,"isCompleted":true}"#.utf8)
        let set = try JSONDecoder().decode(WatchSetData.self, from: legacySet)
        #expect(set.reps == 5)
        #expect(set.plannedReps == nil)
        #expect(set.rpeSourceRaw == nil)
        #expect(set.setTypeRaw == nil)

        let legacyProcedure = Data(#"{"setNumber":1,"weight":80,"reps":5}"#.utf8)
        let procedure = try JSONDecoder().decode(WatchProcedureSetSnapshot.self, from: legacyProcedure)
        #expect(procedure.plannedReps == nil)
        #expect(procedure.rpe == nil)
        #expect(procedure.plannedSetCount == nil)

        let legacyUpdate = Data(#"{"exerciseID":"squat","exerciseName":"Squat","completedSets":[{"setNumber":1,"weight":80,"reps":5,"isCompleted":true}],"startTime":100,"heartRateSamples":[]}"#.utf8)
        let update = try JSONDecoder().decode(WatchWorkoutUpdate.self, from: legacyUpdate)
        #expect(update.completedSets.first?.reps == 5)
        #expect(update.plannedSetCount == nil)
        #expect(update.effortSourceRaw == nil)
    }

    @Test("New workout metadata survives transport encoding")
    func metadataRoundTrip() throws {
        let set = WatchSetData(setNumber: 1, weight: 80, reps: 5, duration: nil,
                               restDuration: nil, isCompleted: true, rpe: 8,
                               plannedReps: 6, rpeSourceRaw: "user", setTypeRaw: "working")
        let update = WatchWorkoutUpdate(exerciseID: "squat", exerciseName: "Squat",
                                        completedSets: [set], startTime: Date(timeIntervalSince1970: 100),
                                        endTime: nil, heartRateSamples: [], rpe: 8,
                                        plannedSetCount: 3, effortSourceRaw: "user")
        let decoded = try JSONDecoder().decode(WatchWorkoutUpdate.self, from: JSONEncoder().encode(update))
        #expect(decoded.plannedSetCount == 3)
        #expect(decoded.effortSourceRaw == "user")
        #expect(decoded.completedSets.first?.reps == 5)
        #expect(decoded.completedSets.first?.plannedReps == 6)
        #expect(decoded.completedSets.first?.rpeSourceRaw == "user")

        let procedure = WatchProcedureSetSnapshot(setNumber: 1, weight: 80, reps: 5,
                                                  plannedReps: 6, rpe: 8, rpeSourceRaw: "user",
                                                  setTypeRaw: "working", plannedSetCount: 3)
        let decodedProcedure = try JSONDecoder().decode(
            WatchProcedureSetSnapshot.self, from: JSONEncoder().encode(procedure)
        )
        #expect(decodedProcedure == procedure)
    }
}
