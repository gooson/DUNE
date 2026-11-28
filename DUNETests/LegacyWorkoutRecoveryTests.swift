import CloudKit
import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("Legacy workout recovery")
@MainActor
struct LegacyWorkoutRecoveryTests {
    private func store() throws -> ModelContainer {
        let schema = Schema([ExerciseRecord.self, WorkoutSet.self])
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
