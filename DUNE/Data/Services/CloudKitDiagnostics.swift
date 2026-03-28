import CloudKit
import OSLog

enum CloudKitDiagnostics: Sendable {
    private static let logger = Logger(subsystem: "com.raftel.dailve", category: "CloudKitDiag")

    @MainActor
    static func fetchAllExerciseRecords() async {
        let container = CKContainer(identifier: "iCloud.com.raftel.dailve")
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )

        logger.info("[Diag] Starting fetch...")

        do {
            var exerciseRecords: [CKRecord] = []
            var workoutSetCount = 0
            var otherTypes: [String: Int] = [:]
            var changeToken: CKServerChangeToken?
            var hasMore = true

            while hasMore {
                let changes = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: changeToken
                )

                for (_, result) in changes.modificationResultsByID {
                    guard case .success(let mod) = result else { continue }
                    let record = mod.record
                    let typeName = record.recordType
                    if typeName == "CD_ExerciseRecord" {
                        exerciseRecords.append(record)
                    } else if typeName == "CD_WorkoutSet" {
                        workoutSetCount += 1
                    } else {
                        otherTypes[typeName, default: 0] += 1
                    }
                }

                changeToken = changes.changeToken
                hasMore = changes.moreComing
            }

            logger.info("[Diag] Total ExerciseRecords: \(exerciseRecords.count)")
            logger.info("[Diag] Total WorkoutSets: \(workoutSetCount)")
            logger.info("[Diag] Other types: \(otherTypes)")

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm"

            let sorted = exerciseRecords.sorted {
                ($0["CD_date"] as? Date ?? .distantPast) < ($1["CD_date"] as? Date ?? .distantPast)
            }

            for r in sorted {
                let d = fmt.string(from: (r["CD_date"] as? Date) ?? .distantPast)
                let t = r["CD_exerciseType"] as? String ?? "?"
                let dur = r["CD_duration"] as? Double ?? 0
                logger.info("[Diag] \(d) | \(t) | \(Int(dur))s")
            }

            let march7 = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 7))!
            let after = sorted.filter { ($0["CD_date"] as? Date ?? .distantPast) >= march7 }
            logger.info("[Diag] After 2026-03-07: \(after.count)")
            logger.info("[Diag] DONE")

        } catch {
            logger.error("[Diag] FAILED: \(error)")
        }
    }
}
