import Foundation
import SwiftData

/// Deletes independently stored location metadata with its owning workout in the caller's context.
@MainActor
enum WorkoutLocationRecordCleanup {
    static func delete(
        localRecordID: UUID? = nil,
        healthKitWorkoutID: String? = nil,
        from context: ModelContext
    ) throws {
        guard localRecordID != nil || (healthKitWorkoutID?.isEmpty == false) else { return }

        var matches: [WorkoutLocationRecord] = []
        if let localRecordID {
            let predicate = #Predicate<WorkoutLocationRecord> { $0.localRecordID == localRecordID }
            matches += try context.fetch(FetchDescriptor(predicate: predicate))
        }
        if let healthKitWorkoutID, !healthKitWorkoutID.isEmpty {
            let predicate = #Predicate<WorkoutLocationRecord> { $0.healthKitWorkoutID == healthKitWorkoutID }
            matches += try context.fetch(FetchDescriptor(predicate: predicate))
        }

        var seen = Set<ObjectIdentifier>()
        for record in matches where seen.insert(ObjectIdentifier(record)).inserted {
            context.delete(record)
        }
    }
}
