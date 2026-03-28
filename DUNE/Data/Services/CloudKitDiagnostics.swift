import CloudKit
import SwiftData
import OSLog

enum CloudKitDiagnostics: Sendable {
    private static let logger = Logger(subsystem: "com.raftel.dailve", category: "CloudKitDiag")

    /// Dump local SwiftData ExerciseRecord status to diagnose missing set data.
    @MainActor
    static func diagnoseLocalRecords(modelContainer: ModelContainer) async {
        let context = ModelContext(modelContainer)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"

        do {
            let records = try context.fetch(
                FetchDescriptor<ExerciseRecord>(sortBy: [SortDescriptor(\.date)])
            )
            logger.info("[Diag] Local ExerciseRecords: \(records.count)")

            for r in records {
                let d = fmt.string(from: r.date)
                let setsCount = (r.sets ?? []).count
                let completedCount = r.completedSets.count
                let hasSet = r.hasSetData
                let vol = r.totalVolume
                logger.info("[Diag] \(d) | \(r.exerciseType) | sets:\(setsCount) completed:\(completedCount) hasSetData:\(hasSet) vol:\(vol)")
            }

            // Check WorkoutSets separately
            let allSets = try context.fetch(FetchDescriptor<WorkoutSet>())
            let orphanSets = allSets.filter { $0.exerciseRecord == nil }
            logger.info("[Diag] Total WorkoutSets: \(allSets.count), orphans (no parent): \(orphanSets.count)")

            logger.info("[Diag] DONE")
        } catch {
            logger.error("[Diag] FAILED: \(error)")
        }
    }
}
