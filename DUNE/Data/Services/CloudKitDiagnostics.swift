import CloudKit
import SwiftData
import OSLog

enum CloudKitDiagnostics: Sendable {
    private static let logger = Logger(subsystem: "com.raftel.dailve", category: "CloudKitDiag")

    /// Fetch all ExerciseRecord + WorkoutSet from iCloud and insert missing ones into SwiftData.
    @MainActor
    static func recoverFromCloudKit(modelContainer: ModelContainer) async {
        let container = CKContainer(identifier: "iCloud.com.raftel.dailve")
        let database = container.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: "com.apple.coredata.cloudkit.zone",
            ownerName: CKCurrentUserDefaultName
        )

        logger.info("[Recovery] Starting iCloud recovery...")

        do {
            // 1. Fetch all CKRecords from zone
            var ckExerciseRecords: [CKRecord] = []
            var ckWorkoutSets: [CKRecord] = []
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
                    if record.recordType == "CD_ExerciseRecord" {
                        ckExerciseRecords.append(record)
                    } else if record.recordType == "CD_WorkoutSet" {
                        ckWorkoutSets.append(record)
                    }
                }
                changeToken = changes.changeToken
                hasMore = changes.moreComing
            }

            logger.info("[Recovery] iCloud: \(ckExerciseRecords.count) records, \(ckWorkoutSets.count) sets")

            // 2. Build WorkoutSet lookup by parent ExerciseRecord reference
            var setsByParent: [String: [CKRecord]] = [:]
            for setRecord in ckWorkoutSets {
                if let ref = setRecord["CD_exerciseRecord"] as? CKRecord.Reference {
                    let parentID = ref.recordID.recordName
                    setsByParent[parentID, default: []].append(setRecord)
                }
            }

            // 3. Check existing local records to avoid duplicates
            let context = ModelContext(modelContainer)
            let existingRecords = (try? context.fetch(FetchDescriptor<ExerciseRecord>())) ?? []
            var existingKeys: Set<String> = []
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd HH:mm"
            for rec in existingRecords {
                let key = "\(rec.exerciseType)_\(fmt.string(from: rec.date))"
                existingKeys.insert(key)
            }

            // 4. Insert missing records
            var insertedCount = 0
            var skippedCount = 0

            for ckRecord in ckExerciseRecords {
                let date = ckRecord["CD_date"] as? Date ?? Date.distantPast
                let exerciseType = ckRecord["CD_exerciseType"] as? String ?? ""
                let dedupKey = "\(exerciseType)_\(fmt.string(from: date))"

                if existingKeys.contains(dedupKey) {
                    skippedCount += 1
                    continue
                }

                let duration = ckRecord["CD_duration"] as? Double ?? 0
                let calories = ckRecord["CD_calories"] as? Double
                let distance = ckRecord["CD_distance"] as? Double
                let stepCount = ckRecord["CD_stepCount"] as? Int
                let avgPace = ckRecord["CD_averagePaceSecondsPerKm"] as? Double
                let avgCadence = ckRecord["CD_averageCadenceStepsPerMinute"] as? Double
                let elevation = ckRecord["CD_elevationGainMeters"] as? Double
                let floors = ckRecord["CD_floorsAscended"] as? Double
                let machineLevelAvg = ckRecord["CD_cardioMachineLevelAverage"] as? Double
                let machineLevelMax = ckRecord["CD_cardioMachineLevelMax"] as? Int
                let memo = ckRecord["CD_memo"] as? String ?? ""
                let isFromHealthKit = (ckRecord["CD_isFromHealthKit"] as? Int64 ?? 0) != 0
                let healthKitWorkoutID = ckRecord["CD_healthKitWorkoutID"] as? String
                let exerciseDefinitionID = ckRecord["CD_exerciseDefinitionID"] as? String
                let primaryMusclesRaw = ckRecord["CD_primaryMusclesRaw"] as? [String] ?? []
                let secondaryMusclesRaw = ckRecord["CD_secondaryMusclesRaw"] as? [String] ?? []
                let equipmentRaw = ckRecord["CD_equipmentRaw"] as? String
                let estimatedCalories = ckRecord["CD_estimatedCalories"] as? Double
                let calorieSourceRaw = ckRecord["CD_calorieSourceRaw"] as? String ?? "manual"
                let rpe = ckRecord["CD_rpe"] as? Int
                let autoIntensityRaw = ckRecord["CD_autoIntensityRaw"] as? Double
                let cardioFitnessVO2Max = ckRecord["CD_cardioFitnessVO2Max"] as? Double

                let record = ExerciseRecord(
                    date: date,
                    exerciseType: exerciseType,
                    duration: duration,
                    calories: calories,
                    distance: distance,
                    stepCount: stepCount,
                    averagePaceSecondsPerKm: avgPace,
                    averageCadenceStepsPerMinute: avgCadence,
                    elevationGainMeters: elevation,
                    floorsAscended: floors,
                    cardioMachineLevelAverage: machineLevelAvg,
                    cardioMachineLevelMax: machineLevelMax,
                    memo: memo,
                    isFromHealthKit: isFromHealthKit,
                    healthKitWorkoutID: healthKitWorkoutID,
                    exerciseDefinitionID: exerciseDefinitionID,
                    primaryMuscles: primaryMusclesRaw.compactMap { MuscleGroup(rawValue: $0) },
                    secondaryMuscles: secondaryMusclesRaw.compactMap { MuscleGroup(rawValue: $0) },
                    equipment: equipmentRaw.flatMap { Equipment(rawValue: $0) },
                    estimatedCalories: estimatedCalories,
                    calorieSource: CalorieSource(rawValue: calorieSourceRaw) ?? .manual,
                    rpe: rpe,
                    autoIntensityRaw: autoIntensityRaw,
                    cardioFitnessVO2Max: cardioFitnessVO2Max
                )
                context.insert(record)

                // Insert associated WorkoutSets
                let parentID = ckRecord.recordID.recordName
                let childSets = setsByParent[parentID] ?? []
                var workoutSets: [WorkoutSet] = []

                for ckSet in childSets {
                    let setNumber = ckSet["CD_setNumber"] as? Int ?? 0
                    let weight = ckSet["CD_weight"] as? Double
                    let reps = ckSet["CD_reps"] as? Int
                    let setDuration = ckSet["CD_duration"] as? Double
                    let setDistance = ckSet["CD_distance"] as? Double
                    let intensity = ckSet["CD_intensity"] as? Int
                    let isCompleted = (ckSet["CD_isCompleted"] as? Int64 ?? 0) != 0
                    let restDuration = ckSet["CD_restDuration"] as? Double
                    let setRpe = ckSet["CD_rpe"] as? Double
                    let setTypeRaw = ckSet["CD_setTypeRaw"] as? String ?? "working"

                    let workoutSet = WorkoutSet(
                        setNumber: setNumber,
                        setType: SetType(rawValue: setTypeRaw) ?? .working,
                        weight: weight,
                        reps: reps,
                        duration: setDuration,
                        distance: setDistance,
                        intensity: intensity,
                        isCompleted: isCompleted,
                        restDuration: restDuration,
                        rpe: setRpe
                    )
                    workoutSet.exerciseRecord = record
                    context.insert(workoutSet)
                    workoutSets.append(workoutSet)
                }
                record.sets = workoutSets

                existingKeys.insert(dedupKey)
                insertedCount += 1

                let dateStr = fmt.string(from: date)
                logger.info("[Recovery] Inserted: \(dateStr) | \(exerciseType) | \(workoutSets.count) sets")
            }

            try context.save()
            logger.info("[Recovery] DONE — inserted \(insertedCount), skipped \(skippedCount) duplicates")

        } catch {
            logger.error("[Recovery] FAILED: \(error)")
        }
    }
}
