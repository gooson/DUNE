import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("WorkoutLocationRecordCleanup")
@MainActor
struct WorkoutLocationRecordCleanupTests {
    @Test("A queued remote deletion also removes every local alias including metadata without an HK link")
    func remoteFailureLocalAliases() throws {
        let context = try makeContext()
        let first = UUID()
        let second = UUID()
        let rows = [
            WorkoutLocationRecord(localRecordID: first, payload: WorkoutLocationPayload()),
            WorkoutLocationRecord(localRecordID: second, payload: WorkoutLocationPayload()),
            WorkoutLocationRecord(healthKitWorkoutID: "queued-hk", payload: WorkoutLocationPayload()),
        ]
        let unrelated = WorkoutLocationRecord(localRecordID: UUID(), payload: WorkoutLocationPayload())
        (rows + [unrelated]).forEach { context.insert($0) }
        try context.save()
        try WorkoutLocationRecordCleanup.delete(localRecordIDs: [first, second, first],
                                               healthKitWorkoutID: "queued-hk", from: context)
        try context.save()
        let survivors = try context.fetch(FetchDescriptor<WorkoutLocationRecord>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.id == unrelated.id)
    }
    @Test("A local deletion removes matching local and dual-linked metadata only")
    func deletesByLocalID() throws {
        let context = try makeContext()
        let target = UUID()
        let unrelated = UUID()
        let localOnly = WorkoutLocationRecord(localRecordID: target, payload: WorkoutLocationPayload())
        let dualLinked = WorkoutLocationRecord(localRecordID: target, healthKitWorkoutID: "hk-target", payload: WorkoutLocationPayload())
        let other = WorkoutLocationRecord(localRecordID: unrelated, healthKitWorkoutID: "hk-other", payload: WorkoutLocationPayload())
        let unlinked = WorkoutLocationRecord(payload: WorkoutLocationPayload())
        [localOnly, dualLinked, other, unlinked].forEach { context.insert($0) }
        try context.save()

        try WorkoutLocationRecordCleanup.delete(localRecordID: target, from: context)
        try context.save()

        let survivors = try context.fetch(FetchDescriptor<WorkoutLocationRecord>())
        #expect(Set(survivors.map(\.id)) == Set([other.id, unlinked.id]))
    }

    @Test("A HealthKit deletion removes matching imported and dual-linked metadata only")
    func deletesByHealthKitID() throws {
        let context = try makeContext()
        let imported = WorkoutLocationRecord(healthKitWorkoutID: "hk-target", payload: WorkoutLocationPayload())
        let dualLinked = WorkoutLocationRecord(localRecordID: UUID(), healthKitWorkoutID: "hk-target", payload: WorkoutLocationPayload())
        let other = WorkoutLocationRecord(healthKitWorkoutID: "hk-other", payload: WorkoutLocationPayload())
        let unlinked = WorkoutLocationRecord(payload: WorkoutLocationPayload())
        [imported, dualLinked, other, unlinked].forEach { context.insert($0) }
        try context.save()

        try WorkoutLocationRecordCleanup.delete(healthKitWorkoutID: "hk-target", from: context)
        try context.save()

        let survivors = try context.fetch(FetchDescriptor<WorkoutLocationRecord>())
        #expect(Set(survivors.map(\.id)) == Set([other.id, unlinked.id]))
    }

    @Test("Missing identifiers never match unlinked or unrelated metadata")
    func nilIDsDoNothing() throws {
        let context = try makeContext()
        let unlinked = WorkoutLocationRecord(payload: WorkoutLocationPayload())
        let linked = WorkoutLocationRecord(localRecordID: UUID(), healthKitWorkoutID: "hk", payload: WorkoutLocationPayload())
        [unlinked, linked].forEach { context.insert($0) }
        try context.save()

        try WorkoutLocationRecordCleanup.delete(from: context)
        try WorkoutLocationRecordCleanup.delete(healthKitWorkoutID: "", from: context)
        try context.save()

        let survivors = try context.fetch(FetchDescriptor<WorkoutLocationRecord>())
        #expect(Set(survivors.map(\.id)) == Set([unlinked.id, linked.id]))
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: WorkoutLocationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
}
