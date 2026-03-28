import CloudKit
import SwiftData
import OSLog

enum CloudKitDiagnostics: Sendable {
    private static let logger = Logger(subsystem: "com.raftel.dailve", category: "CloudKitDiag")

    @MainActor
    static func dumpAllCloudKitData(modelContainer: ModelContainer) async {
        let container = CKContainer(identifier: "iCloud.com.raftel.dailve")
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )

        logger.info("[CK] ========== FULL CLOUDKIT DUMP ==========")

        do {
            // Fetch ALL records from zone
            var allRecords: [CKRecord] = []
            var changeToken: CKServerChangeToken?
            var hasMore = true

            while hasMore {
                let changes = try await database.recordZoneChanges(
                    inZoneWith: zoneID,
                    since: changeToken
                )
                for (_, result) in changes.modificationResultsByID {
                    guard case .success(let mod) = result else { continue }
                    allRecords.append(mod.record)
                }
                changeToken = changes.changeToken
                hasMore = changes.moreComing
            }

            // Group by type
            var byType: [String: [CKRecord]] = [:]
            for r in allRecords {
                byType[r.recordType, default: []].append(r)
            }

            logger.info("[CK] Total records: \(allRecords.count)")
            for (type, records) in byType.sorted(by: { $0.key < $1.key }) {
                logger.info("[CK] \(type): \(records.count)")
            }

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm"

            // ===== ExerciseRecord =====
            logger.info("[CK] ----- CD_ExerciseRecord -----")
            let exercises = (byType["CD_ExerciseRecord"] ?? []).sorted {
                ($0["CD_date"] as? Date ?? .distantPast) < ($1["CD_date"] as? Date ?? .distantPast)
            }
            for r in exercises {
                let d = fmt.string(from: (r["CD_date"] as? Date) ?? .distantPast)
                let t = r["CD_exerciseType"] as? String ?? "?"
                let dur = r["CD_duration"] as? Double ?? 0
                let defID = r["CD_exerciseDefinitionID"] as? String ?? "-"
                let cal = r["CD_calories"] as? Double
                let estCal = r["CD_estimatedCalories"] as? Double
                let rpe = r["CD_rpe"] as? Int
                let hkID = r["CD_healthKitWorkoutID"] as? String ?? "-"
                let equip = r["CD_equipmentRaw"] as? String ?? "-"
                let primary = r["CD_primaryMusclesRaw"] as? [String] ?? []
                logger.info("[CK] \(d) | \(t) | \(Int(dur))s | defID:\(defID) | cal:\(cal ?? -1) estCal:\(estCal ?? -1) | rpe:\(rpe ?? -1) | hk:\(hkID) | equip:\(equip) | muscles:\(primary)")
            }

            // ===== WorkoutSet =====
            logger.info("[CK] ----- CD_WorkoutSet -----")
            let sets = byType["CD_WorkoutSet"] ?? []
            // Group by parent
            var setsByParent: [String: [CKRecord]] = [:]
            for s in sets {
                let parentID: String
                if let ref = s["CD_exerciseRecord"] as? CKRecord.Reference {
                    parentID = ref.recordID.recordName
                } else {
                    parentID = "orphan"
                }
                setsByParent[parentID, default: []].append(s)
            }

            // Map exercise recordName to exercise info
            var exerciseByRecordName: [String: (date: String, name: String)] = [:]
            for r in exercises {
                let d = fmt.string(from: (r["CD_date"] as? Date) ?? .distantPast)
                let t = r["CD_exerciseType"] as? String ?? "?"
                exerciseByRecordName[r.recordID.recordName] = (d, t)
            }

            for (parentID, parentSets) in setsByParent.sorted(by: { ($0.value.first?["CD_setNumber"] as? Int ?? 0) < ($1.value.first?["CD_setNumber"] as? Int ?? 0) }) {
                let parentInfo = exerciseByRecordName[parentID]
                let label = parentInfo.map { "\($0.date) \($0.name)" } ?? parentID
                let sorted = parentSets.sorted { ($0["CD_setNumber"] as? Int ?? 0) < ($1["CD_setNumber"] as? Int ?? 0) }
                for s in sorted {
                    let num = s["CD_setNumber"] as? Int ?? 0
                    let w = s["CD_weight"] as? Double
                    let reps = s["CD_reps"] as? Int
                    let completed = (s["CD_isCompleted"] as? Int64 ?? 0) != 0
                    let setRpe = s["CD_rpe"] as? Double
                    let rest = s["CD_restDuration"] as? Double
                    let setType = s["CD_setTypeRaw"] as? String ?? "working"
                    logger.info("[CK] [\(label)] set\(num) \(w ?? 0)kg x \(reps ?? 0) | done:\(completed) | type:\(setType) | rpe:\(setRpe ?? -1) | rest:\(rest ?? -1)")
                }
            }

            // ===== ExerciseDefaultRecord =====
            logger.info("[CK] ----- CD_ExerciseDefaultRecord -----")
            let defaults = byType["CD_ExerciseDefaultRecord"] ?? []
            for r in defaults {
                let defID = r["CD_exerciseDefinitionID"] as? String ?? "?"
                let weight = r["CD_defaultWeight"] as? Double
                let reps = r["CD_defaultReps"] as? Int
                let preferred = (r["CD_isPreferred"] as? Int64 ?? 0) != 0
                let manual = (r["CD_isManualOverride"] as? Int64 ?? 0) != 0
                let lastUsed = r["CD_lastUsedDate"] as? Date
                let lastStr = lastUsed.map { fmt.string(from: $0) } ?? "-"
                logger.info("[CK] \(defID) | w:\(weight ?? -1) r:\(reps ?? -1) | pref:\(preferred) manual:\(manual) | last:\(lastStr)")
            }

            // ===== WorkoutTemplate =====
            logger.info("[CK] ----- CD_WorkoutTemplate -----")
            let templates = byType["CD_WorkoutTemplate"] ?? []
            for r in templates {
                let name = r["CD_name"] as? String ?? "?"
                let updated = r["CD_updatedAt"] as? Date
                let updStr = updated.map { fmt.string(from: $0) } ?? "-"
                logger.info("[CK] \(name) | updated:\(updStr)")
            }

            // ===== Local vs iCloud comparison =====
            logger.info("[CK] ----- LOCAL vs ICLOUD -----")
            let context = ModelContext(modelContainer)
            let localRecords = (try? context.fetch(FetchDescriptor<ExerciseRecord>())) ?? []
            let localSets = (try? context.fetch(FetchDescriptor<WorkoutSet>())) ?? []
            let localDefaults = (try? context.fetch(FetchDescriptor<ExerciseDefaultRecord>())) ?? []
            logger.info("[CK] Local ExerciseRecords: \(localRecords.count) | iCloud: \(exercises.count)")
            logger.info("[CK] Local WorkoutSets: \(localSets.count) | iCloud: \(sets.count)")
            logger.info("[CK] Local ExerciseDefaults: \(localDefaults.count) | iCloud: \(defaults.count)")

            logger.info("[CK] ========== DUMP COMPLETE ==========")

        } catch {
            logger.error("[CK] FAILED: \(error)")
        }
    }
}
