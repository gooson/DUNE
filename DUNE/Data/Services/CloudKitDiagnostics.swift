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
            // 1. Zone 확인
            let zones = try await database.allRecordZones()
            logger.info("[Diag] Zones: \(zones.map(\.zoneID.zoneName))")

            // 2. ExerciseRecord 조회
            let query = CKQuery(recordType: "CD_ExerciseRecord", predicate: NSPredicate(value: true))
            var allRecords: [CKRecord] = []

            let (firstResults, firstCursor) = try await database.records(
                matching: query,
                inZoneWith: zoneID
            )
            for case (_, .success(let r)) in firstResults { allRecords.append(r) }

            var cursor = firstCursor
            while let c = cursor {
                let (moreResults, nextCursor) = try await database.records(continuingMatchFrom: c)
                for case (_, .success(let r)) in moreResults { allRecords.append(r) }
                cursor = nextCursor
            }

            logger.info("[Diag] Total ExerciseRecords: \(allRecords.count)")

            // 3. 각 레코드 출력
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm"

            let sorted = allRecords.sorted {
                ($0["CD_date"] as? Date ?? .distantPast) < ($1["CD_date"] as? Date ?? .distantPast)
            }
            for r in sorted {
                let d = fmt.string(from: (r["CD_date"] as? Date) ?? .distantPast)
                let t = r["CD_exerciseType"] as? String ?? "?"
                let dur = r["CD_duration"] as? Double ?? 0
                logger.info("[Diag] \(d) | \(t) | \(Int(dur))s")
            }

            // 4. WorkoutSet 개수
            let setQuery = CKQuery(recordType: "CD_WorkoutSet", predicate: NSPredicate(value: true))
            let (setResults, _) = try await database.records(matching: setQuery, inZoneWith: zoneID)
            var setCount = 0
            for case (_, .success) in setResults { setCount += 1 }
            logger.info("[Diag] Total WorkoutSets: \(setCount)")

            // 5. 3/7 이후
            let march7 = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 7))!
            let after = sorted.filter { ($0["CD_date"] as? Date ?? .distantPast) >= march7 }
            logger.info("[Diag] After 2026-03-07: \(after.count)")
            logger.info("[Diag] DONE")

        } catch {
            logger.error("[Diag] FAILED: \(error)")
        }
    }
}
