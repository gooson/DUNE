import CloudKit
import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("Legacy workout recovery")
@MainActor
struct LegacyWorkoutRecoveryTests {
    private func store() throws -> ModelContainer {
        let schema = Schema([ExerciseRecord.self, WorkoutSet.self, WorkoutLocationRecord.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        ))
    }

    private func workout() -> CKRecord {
        let record = CKRecord(recordType: "CD_ExerciseRecord")
        record["CD_id"] = UUID().uuidString
        record["CD_date"] = Date(timeIntervalSince1970: 100)
        record["CD_createdAt"] = Date(timeIntervalSince1970: 200)
        record["CD_exerciseType"] = "Walking"
        record["CD_duration"] = NSNumber(value: 60)
        return record
    }

    private func set(parent: CKRecord) -> CKRecord {
        let record = CKRecord(recordType: "CD_WorkoutSet")
        record["CD_id"] = UUID().uuidString
        record["CD_exerciseRecord"] = parent.recordID.recordName
        record["CD_setNumber"] = NSNumber(value: 1)
        record["CD_reps"] = NSNumber(value: 8)
        return record
    }

    @Test func restoresHistoricalLocationAndPreservesLocalEdits() throws {
        let container = try store()
        let exercise = workout()
        let record = CKRecord(recordType: "CD_WorkoutLocationRecord")
        let healthID = UUID().uuidString
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let place = try #require(WorkoutPlace(latitude: 12, longitude: 22, name: "Fixture gym", source: .manual))
        let route = try #require(WorkoutRoutePoint(latitude: 12.1, longitude: 22.1, timestamp: stamp))
        let payload = WorkoutLocationPayload(isIndoor: true, route: [route], place: place)
        record["CD_id"] = UUID().uuidString
        record["CD_localRecordID"] = exercise["CD_id"]
        record["CD_healthKitWorkoutID"] = healthID
        record["CD_updatedAt"] = stamp
        let bytes = try JSONEncoder().encode(payload)
        let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try bytes.write(to: file)
        record["CD_payloadData_ckAsset"] = CKAsset(fileURL: file)
        let first = try LegacyWorkoutRecovery.importRecords([record, exercise], into: container)
        #expect(first.locations == 1)
        let context = ModelContext(container)
        let row = try #require(context.fetch(FetchDescriptor<WorkoutLocationRecord>()).first)
        #expect(row.localRecordID?.uuidString == exercise["CD_id"] as? String)
        #expect(row.healthKitWorkoutID == healthID)
        #expect(row.payloadData == bytes && row.updatedAt == stamp)
        #expect(row.payload == payload)
        #expect(try LegacyWorkoutRecovery.importRecords([record, exercise], into: container).locations == 0)
        row.payload = WorkoutLocationPayload(isIndoor: true)
        try context.save()
        #expect(throws: LegacyWorkoutRecovery.Failure.localConflict) {
            try LegacyWorkoutRecovery.importRecords([workout(), record], into: container)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 1)
        #expect(try ModelContext(container).fetch(FetchDescriptor<WorkoutLocationRecord>()).first?.payload?.place == nil)
    }

    @Test func mixedVersionRecoveryRetainsNewerFieldsAndFillsOnlyMissingValues() throws {
        let container = try store()
        let original = workout(), trainingSet = set(parent: original)
        original["CD_plannedSetCount"] = NSNumber(value: 4)
        trainingSet["CD_rpeSourceRaw"] = "manual"
        _ = try LegacyWorkoutRecovery.importRecords([original, trainingSet], into: container)

        original["CD_plannedSetCount"] = nil
        trainingSet["CD_rpeSourceRaw"] = nil
        original["CD_effortSourceRaw"] = "user"
        trainingSet["CD_plannedReps"] = NSNumber(value: 8)
        let extra = workout()
        let records = [original, trainingSet, extra]
        #expect(try LegacyWorkoutRecovery.importRecords(records, into: container).workouts == 1)
        #expect(try LegacyWorkoutRecovery.importRecords(records, into: container).workouts == 0)
        let context = ModelContext(container)
        let set = try #require(context.fetch(FetchDescriptor<WorkoutSet>()).first)
        #expect(set.rpeSourceRaw == "manual" && set.plannedReps == 8)
        #expect(set.exerciseRecord?.plannedSetCount == 4 && set.exerciseRecord?.effortSourceRaw == "user")

        trainingSet["CD_plannedReps"] = NSNumber(value: 10)
        #expect(throws: LegacyWorkoutRecovery.Failure.localConflict) {
            try LegacyWorkoutRecovery.importRecords([workout()] + records, into: container)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 2)
        #expect(try ModelContext(container).fetch(FetchDescriptor<WorkoutSet>()).first?.plannedReps == 8)
    }

    @Test func resolvesParentsAcrossPagesAndRepeatedImports() throws {
        let container = try store()
        let first = workout(), second = workout()
        let pages = [[set(parent: second)], [first, set(parent: first)], [second]]
        let records = pages.flatMap { $0 }
        let added = try LegacyWorkoutRecovery.importRecords(records, into: container)
        #expect(added.workouts == 2 && added.sets == 2)
        let repeatResult = try LegacyWorkoutRecovery.importRecords(records, into: container)
        #expect(repeatResult.workouts == 0 && repeatResult.sets == 0)
        let sets = try ModelContext(container).fetch(FetchDescriptor<WorkoutSet>())
        #expect(Set(sets.compactMap { $0.exerciseRecord?.id }).count == 2)
        #expect(sets.allSatisfy { $0.reps == 8 })
    }

    @Test func retainsSeparateExercisesLinkedToOneHealthKitSession() throws {
        let container = try store()
        let first = workout(), second = workout()
        let healthID = UUID().uuidString
        first["CD_healthKitWorkoutID"] = healthID
        second["CD_healthKitWorkoutID"] = healthID.lowercased()
        _ = try LegacyWorkoutRecovery.importRecords([first], into: container)
        let result = try LegacyWorkoutRecovery.importRecords([first, second], into: container)
        #expect(result.workouts == 1)
        let count = try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>())
        #expect(count == 2)
        let repeated = try LegacyWorkoutRecovery.importRecords([second, first], into: container)
        #expect(repeated.workouts == 0)
    }

    @Test func rejectsIdentifiersAlreadyDuplicatedOnDevice() throws {
        let container = try store()
        let context = ModelContext(container)
        let domainID = UUID()
        for _ in 0..<2 {
            let row = ExerciseRecord(date: .now, exerciseType: "Walking", duration: 30)
            row.id = domainID
            context.insert(row)
        }
        try context.save()
        #expect(throws: LegacyWorkoutRecovery.Failure.duplicateIdentity) {
            try LegacyWorkoutRecovery.importRecords([workout()], into: container)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 2)
    }

    @Test func orphanRollsBackEarlierInsertions() throws {
        let container = try store()
        #expect(throws: LegacyWorkoutRecovery.Failure.invalidRelationship) {
            try LegacyWorkoutRecovery.importRecords([workout(), set(parent: workout())], into: container)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 0)
    }

    @Test func preservesLocalAndRemoteEditsOnConflict() throws {
        let container = try store()
        let source = workout(), child = set(parent: source)
        _ = try LegacyWorkoutRecovery.importRecords([source, child], into: container)
        let context = ModelContext(container)
        let local = try #require(context.fetch(FetchDescriptor<ExerciseRecord>()).first)
        local.memo = "device edit"
        try context.save()
        source["CD_memo"] = "cloud edit"
        #expect(throws: LegacyWorkoutRecovery.Failure.localConflict) {
            try LegacyWorkoutRecovery.importRecords([workout(), source, child], into: container)
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<ExerciseRecord>()).map(\.memo) == ["device edit"])
        #expect(source["CD_memo"] as? String == "cloud edit")
        source["CD_memo"] = "device edit"
        child["CD_reps"] = NSNumber(value: 9)
        #expect(throws: LegacyWorkoutRecovery.Failure.localConflict) {
            try LegacyWorkoutRecovery.importRecords([source, child], into: container)
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<WorkoutSet>()).first?.reps == 8)
    }

    @Test func refusesMalformedOptionalNumbersAndBinaryAssets() throws {
        let container = try store()
        let record = workout()
        record["CD_distance"] = "5"
        #expect(throws: LegacyWorkoutRecovery.Failure.invalidRecord) {
            try LegacyWorkoutRecovery.importRecords([record], into: container)
        }
        record["CD_distance"] = nil
        record["CD_stepCount"] = NSNumber(value: 2.5)
        #expect(throws: LegacyWorkoutRecovery.Failure.invalidRecord) {
            try LegacyWorkoutRecovery.importRecords([record], into: container)
        }
        record["CD_stepCount"] = nil
        record["CD_cardioMachineLevelChangesData_ckAsset"] = "invalid asset"
        #expect(throws: LegacyWorkoutRecovery.Failure.invalidRecord) {
            try LegacyWorkoutRecovery.importRecords([record], into: container)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 0)
    }
}
