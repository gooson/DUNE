import CloudKit
import Foundation
import SwiftData

/// Reads historical workout, set and location records without modifying the remote zone. Only explicit recovery inserts local rows.
enum LegacyWorkoutRecovery {
    enum Failure: Error, Equatable { case invalidRecord, invalidRelationship, duplicateIdentity, localConflict, accountChanged, inProgress }

    struct Result {
        let workouts: Int
        let sets: Int
        let locations: Int
    }

    private static let workoutType = "CD_ExerciseRecord"
    private static let setType = "CD_WorkoutSet"
    private static let locationType = "CD_WorkoutLocationRecord"

    static func fetch() async throws -> (account: CKRecord.ID, records: [CKRecord]) {
        let container = CKContainer(identifier: "iCloud.com.raftel.dailve")
        let account = try await container.userRecordID()
        let db = container.privateCloudDatabase
        let zone = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)
        var records = [CKRecord.ID: CKRecord]()
        var token: CKServerChangeToken?
        repeat {
            try Task.checkCancellation()
            let page = try await db.recordZoneChanges(inZoneWith: zone, since: token, resultsLimit: 400)
            for (id, change) in page.modificationResultsByID {
                let record = try change.get().record
                if [workoutType, setType, locationType].contains(record.recordType) { records[id] = record }
            }
            for deletion in page.deletions { records.removeValue(forKey: deletion.recordID) }
            token = page.changeToken
            if !page.moreComing { break }
        } while true
        guard try await container.userRecordID() == account else { throw Failure.accountChanged }
        return (account, Array(records.values))
    }

    @MainActor private static var isRestoring = false

    @MainActor
    static func restore(into container: ModelContainer) async throws -> Result {
        guard !isRestoring else { throw Failure.inProgress }
        isRestoring = true
        defer { isRestoring = false }
        let snapshot = try await fetch()
        try Task.checkCancellation()
        return try importRecords(snapshot.records, into: container)
    }

    @MainActor
    static func importRecords(_ records: [CKRecord], into container: ModelContainer) throws -> Result {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        defer { if context.hasChanges { context.rollback() } }
        // A HealthKit session can contain multiple DUNE exercises. DUNE row IDs identify those exercises.
        var localWorkouts = [UUID: ExerciseRecord]()
        var localSets = [UUID: WorkoutSet]()
        for w in try context.fetch(FetchDescriptor<ExerciseRecord>()) {
            guard localWorkouts.updateValue(w, forKey: w.id) == nil else { throw Failure.duplicateIdentity }
        }
        for s in try context.fetch(FetchDescriptor<WorkoutSet>()) {
            guard localSets.updateValue(s, forKey: s.id) == nil else { throw Failure.duplicateIdentity }
        }
        var parents = [String: ExerciseRecord]()
        var seenWorkouts = Set<UUID>(), seenSets = Set<UUID>()
        var insertedWorkouts = 0, insertedSets = 0
        for r in records where r.recordType == workoutType {
            let id = try identifier(r)
            guard seenWorkouts.insert(id).inserted else { throw Failure.duplicateIdentity }
            let decoded = try workout(r, id: id)
            let row: ExerciseRecord
            if let existing = localWorkouts[id] {
                guard matches(existing, decoded) else { throw Failure.localConflict }
                try supplement(\.plannedSetCount, on: existing, from: decoded)
                try supplement(\.effortSourceRaw, on: existing, from: decoded)
                row = existing
            } else {
                row = decoded
                context.insert(row)
                insertedWorkouts += 1
            }
            guard parents.updateValue(row, forKey: r.recordID.recordName) == nil else { throw Failure.duplicateIdentity }
        }
        for r in records where r.recordType == setType {
            let id = try identifier(r)
            guard seenSets.insert(id).inserted else { throw Failure.duplicateIdentity }
            guard let key = r["CD_exerciseRecord"] as? String, let parent = parents[key] else {
                throw Failure.invalidRelationship
            }
            let set = try workoutSet(r, id: id)
            if let existing = localSets[id] {
                guard existing.exerciseRecord?.id == parent.id else { throw Failure.invalidRelationship }
                guard matches(existing, set) else { throw Failure.localConflict }
                try supplement(\.plannedReps, on: existing, from: set)
                try supplement(\.rpeSourceRaw, on: existing, from: set)
                continue
            }
            set.exerciseRecord = parent
            context.insert(set)
            insertedSets += 1
        }
        let insertedLocations = try restoreLocations(records.filter { $0.recordType == locationType }, into: context)
        if context.hasChanges { try context.save() }
        return Result(workouts: insertedWorkouts, sets: insertedSets, locations: insertedLocations)
    }

    private static func restoreLocations(_ records: [CKRecord], into context: ModelContext) throws -> Int {
        guard !records.isEmpty else { return 0 }
        var local = [UUID: WorkoutLocationRecord]()
        for row in try context.fetch(FetchDescriptor<WorkoutLocationRecord>()) {
            guard local.updateValue(row, forKey: row.id) == nil else { throw Failure.duplicateIdentity }
        }
        var seen = Set<UUID>()
        var inserted = 0
        for record in records {
            let id = try identifier(record)
            guard seen.insert(id).inserted else { throw Failure.duplicateIdentity }
            let localID = try value(record, "CD_localRecordID", as: String.self).map { string in
                guard let uuid = UUID(uuidString: string) else { throw Failure.invalidRecord }
                return uuid
            }
            let healthID = try value(record, "CD_healthKitWorkoutID", as: String.self)
            guard localID != nil || healthID?.isEmpty == false,
                  let date = record["CD_updatedAt"] as? Date else { throw Failure.invalidRecord }
            let data = try binary(record, "CD_payloadData")
            if let data {
                guard data.count <= 1_000_000,
                      (try? JSONDecoder().decode(WorkoutLocationPayload.self, from: data)) != nil
                else { throw Failure.invalidRecord }
            }
            if let existing = local[id] {
                guard existing.localRecordID == localID, existing.healthKitWorkoutID == healthID,
                      abs(existing.updatedAt.timeIntervalSince(date)) < 0.0011 else { throw Failure.localConflict }
                if existing.payloadData != data {
                    // Older encoders can order JSON keys differently for the same recorded location.
                    guard let existingData = existing.payloadData, let data,
                          let previous = try JSONSerialization.jsonObject(with: existingData) as? NSDictionary,
                          let incoming = try JSONSerialization.jsonObject(with: data) as? NSDictionary,
                          previous.isEqual(incoming) else { throw Failure.localConflict }
                }
                continue
            }
            let row = WorkoutLocationRecord(localRecordID: localID, healthKitWorkoutID: healthID, payload: .init())
            row.id = id
            row.payloadData = data
            row.updatedAt = date
            context.insert(row)
            inserted += 1
        }
        return inserted
    }

    private static func identifier(_ r: CKRecord) throws -> UUID {
        guard let key = r["CD_id"] as? String, let id = UUID(uuidString: key) else { throw Failure.invalidRecord }
        return id
    }

    private static func value<T>(_ r: CKRecord, _ key: String, as type: T.Type) throws -> T? {
        guard let field = r[key] else { return nil }
        guard let typed = field as? T else { throw Failure.invalidRecord }
        return typed
    }

    private static func number(_ r: CKRecord, _ key: String) throws -> Double? {
        guard let n = try value(r, key, as: NSNumber.self) else { return nil }
        guard n.doubleValue.isFinite else { throw Failure.invalidRecord }
        return n.doubleValue
    }

    private static func integer(_ r: CKRecord, _ key: String) throws -> Int? {
        guard let n = try value(r, key, as: NSNumber.self) else { return nil }
        let i = n.intValue
        guard n.compare(NSNumber(value: i)) == .orderedSame else { throw Failure.invalidRecord }
        return i
    }

    private static func flag(_ r: CKRecord, _ key: String) throws -> Bool? {
        guard let i = try integer(r, key) else { return nil }
        guard i == 0 || i == 1 else { throw Failure.invalidRecord }
        return i == 1
    }

    private static func binary(_ r: CKRecord, _ key: String) throws -> Data? {
        let inline = r[key]
        let external = r[key + "_ckAsset"]
        guard inline != nil || external != nil else { return nil }
        guard inline == nil || external == nil else { throw Failure.invalidRecord }
        if let data = inline as? Data {
            guard data.count <= 1_048_576 else { throw Failure.invalidRecord }
            return data
        }
        guard let asset = (external ?? inline) as? CKAsset, let url = asset.fileURL,
              let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size >= 0 && size <= 1_048_576 else { throw Failure.invalidRecord }
        let data = try Data(contentsOf: url)
        guard data.count == size else { throw Failure.invalidRecord }
        return data
    }

    private static func muscleList(_ r: CKRecord, _ key: String) throws -> [String] {
        if let list = r[key] as? [String], r[key + "_ckAsset"] == nil { return list }
        guard let data = try binary(r, key) else { return [] }
        guard let list = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSString.self], from: data) as? [String]
        else { throw Failure.invalidRecord }
        return list
    }

    private static func equal<R, V: Equatable>(_ lhs: R, _ rhs: R, _ keys: [KeyPath<R, V>]) -> Bool {
        keys.allSatisfy { lhs[keyPath: $0] == rhs[keyPath: $0] }
    }

    /// V17 backups omit these later fields. Retain the one available value, and reject competing values.
    private static func supplement<Row: AnyObject, Value: Equatable>(
        _ key: ReferenceWritableKeyPath<Row, Value?>, on local: Row, from remote: Row
    ) throws {
        guard let incoming = remote[keyPath: key] else { return }
        if let current = local[keyPath: key] {
            guard current == incoming else { throw Failure.localConflict }
        } else {
            local[keyPath: key] = incoming
        }
    }

    private static func matches(_ a: ExerciseRecord, _ b: ExerciseRecord) -> Bool {
        // CloudKit timestamp transport has millisecond precision.
        abs(a.date.timeIntervalSince(b.date)) < 0.0011 && abs(a.createdAt.timeIntervalSince(b.createdAt)) < 0.0011
            && equal(a, b, [\.exerciseType, \.memo, \.calorieSourceRaw])
            && equal(a, b, [\.exerciseDefinitionID, \.equipmentRaw, \.healthKitWorkoutID])
            && equal(a, b, [\.duration]) && equal(a, b, [\.isFromHealthKit])
            && equal(a, b, [\.primaryMusclesRaw, \.secondaryMusclesRaw])
            && equal(a, b, [\.cardioMachineLevelChangesData])
            && equal(a, b, [\.calories, \.distance, \.averagePaceSecondsPerKm, \.averageCadenceStepsPerMinute,
                            \.elevationGainMeters, \.floorsAscended, \.cardioMachineLevelAverage, \.estimatedCalories,
                            \.autoIntensityRaw, \.cardioFitnessVO2Max])
            && equal(a, b, [\.stepCount, \.cardioMachineLevelMax, \.rpe])
    }

    private static func matches(_ a: WorkoutSet, _ b: WorkoutSet) -> Bool {
        equal(a, b, [\.setNumber]) && equal(a, b, [\.setTypeRaw]) && equal(a, b, [\.isCompleted])
            && equal(a, b, [\.reps, \.intensity])
            && equal(a, b, [\.weight, \.distance, \.duration, \.restDuration, \.rpe])
    }

    private static func workout(_ r: CKRecord, id: UUID) throws -> ExerciseRecord {
        guard let date = r["CD_date"] as? Date, let created = r["CD_createdAt"] as? Date,
              let name = r["CD_exerciseType"] as? String, let duration = try number(r, "CD_duration")
        else { throw Failure.invalidRecord }
        let w = ExerciseRecord(date: date, exerciseType: name, duration: duration)
        w.id = id
        w.createdAt = created
        w.primaryMusclesRaw = try muscleList(r, "CD_primaryMusclesRaw")
        w.secondaryMusclesRaw = try muscleList(r, "CD_secondaryMusclesRaw")
        w.memo = try value(r, "CD_memo", as: String.self) ?? ""
        w.isFromHealthKit = try flag(r, "CD_isFromHealthKit") ?? false
        w.healthKitWorkoutID = try value(r, "CD_healthKitWorkoutID", as: String.self)
        w.exerciseDefinitionID = try value(r, "CD_exerciseDefinitionID", as: String.self)
        w.equipmentRaw = try value(r, "CD_equipmentRaw", as: String.self)
        w.effortSourceRaw = try value(r, "CD_effortSourceRaw", as: String.self)
        w.calorieSourceRaw = try value(r, "CD_calorieSourceRaw", as: String.self) ?? CalorieSource.manual.rawValue
        w.cardioMachineLevelChangesData = try binary(r, "CD_cardioMachineLevelChangesData")
        w.calories = try number(r, "CD_calories")
        w.distance = try number(r, "CD_distance")
        w.averagePaceSecondsPerKm = try number(r, "CD_averagePaceSecondsPerKm")
        w.averageCadenceStepsPerMinute = try number(r, "CD_averageCadenceStepsPerMinute")
        w.elevationGainMeters = try number(r, "CD_elevationGainMeters")
        w.floorsAscended = try number(r, "CD_floorsAscended")
        w.cardioMachineLevelAverage = try number(r, "CD_cardioMachineLevelAverage")
        w.estimatedCalories = try number(r, "CD_estimatedCalories")
        w.autoIntensityRaw = try number(r, "CD_autoIntensityRaw")
        w.cardioFitnessVO2Max = try number(r, "CD_cardioFitnessVO2Max")
        w.stepCount = try integer(r, "CD_stepCount")
        w.cardioMachineLevelMax = try integer(r, "CD_cardioMachineLevelMax")
        w.rpe = try integer(r, "CD_rpe")
        w.plannedSetCount = try integer(r, "CD_plannedSetCount")
        return w
    }

    private static func workoutSet(_ r: CKRecord, id: UUID) throws -> WorkoutSet {
        guard let n = try integer(r, "CD_setNumber") else { throw Failure.invalidRecord }
        let s = WorkoutSet(setNumber: n)
        s.id = id
        s.setTypeRaw = try value(r, "CD_setTypeRaw", as: String.self) ?? SetType.working.rawValue
        s.isCompleted = try flag(r, "CD_isCompleted") ?? false
        s.rpeSourceRaw = try value(r, "CD_rpeSourceRaw", as: String.self)
        s.weight = try number(r, "CD_weight")
        s.distance = try number(r, "CD_distance")
        s.duration = try number(r, "CD_duration")
        s.restDuration = try number(r, "CD_restDuration")
        s.rpe = try number(r, "CD_rpe")
        s.reps = try integer(r, "CD_reps")
        s.intensity = try integer(r, "CD_intensity")
        s.plannedReps = try integer(r, "CD_plannedReps")
        return s
    }
}
