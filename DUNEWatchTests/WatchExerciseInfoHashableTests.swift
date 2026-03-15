import Foundation
import Testing
@testable import DUNEWatch

@Suite("WatchExerciseInfo Hashable")
struct WatchExerciseInfoHashableTests {
    @Test("Equality and hash use ID only")
    func equalityAndHashUseIDOnly() {
        let lhs = WatchExerciseInfo(
            id: "same-id",
            name: "Bench Press",
            inputType: "weight_reps",
            defaultSets: 3,
            defaultReps: 10,
            defaultWeightKg: 60,
            equipment: "barbell",
            cardioSecondaryUnit: nil
        )
        let rhs = WatchExerciseInfo(
            id: "same-id",
            name: "Different Name",
            inputType: "duration",
            defaultSets: 5,
            defaultReps: nil,
            defaultWeightKg: nil,
            equipment: nil,
            cardioSecondaryUnit: "distance"
        )

        #expect(lhs == rhs)
        #expect(Set([lhs, rhs]).count == 1)
    }

    @Test("Different IDs remain distinct")
    func differentIDsAreDistinct() {
        let lhs = WatchExerciseInfo(
            id: "id-1",
            name: "Bench Press",
            inputType: "weight_reps",
            defaultSets: 3,
            defaultReps: 10,
            defaultWeightKg: 60,
            equipment: "barbell",
            cardioSecondaryUnit: nil
        )
        let rhs = WatchExerciseInfo(
            id: "id-2",
            name: "Bench Press",
            inputType: "weight_reps",
            defaultSets: 3,
            defaultReps: 10,
            defaultWeightKg: 60,
            equipment: "barbell",
            cardioSecondaryUnit: nil
        )

        #expect(lhs != rhs)
        #expect(Set([lhs, rhs]).count == 2)
    }

    @Test("Decoding older payload defaults preferred flag to false")
    func decodeWithoutPreferredFlagDefaultsFalse() throws {
        let data = Data(
            """
            {
              "id": "bench-press",
              "name": "Bench Press",
              "inputType": "weight_reps",
              "defaultSets": 3,
              "defaultReps": 10,
              "defaultWeightKg": 60,
              "equipment": "barbell",
              "cardioSecondaryUnit": null
            }
            """.utf8
        )

        let decoded = try JSONDecoder().decode(WatchExerciseInfo.self, from: data)
        #expect(decoded.isPreferred == false)
        #expect(decoded.lastUsedAt == nil)
        #expect(decoded.usageCount == 0)
        #expect(decoded.procedureSets == nil)
        #expect(decoded.procedureUpdatedAt == nil)
        #expect(decoded.progressionIncrementKg == nil)
    }
}
