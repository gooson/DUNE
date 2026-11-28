import Foundation
import CoreFoundation
import CloudKit
import SwiftData

private protocol LegacyCloudOptional {}
extension Optional: LegacyCloudOptional {}

/// Plaintext for the user-directed encrypted archive. Never persist these bytes as a staging file.
@MainActor
enum AppOwnedBackup {
    enum Failure: Error, Equatable {
        case unsupportedVersion, invalidArchive, missingParent, duplicateIdentity, destinationConflict, unsavedChanges
    }

    struct RestoreResult: Equatable {
        let archiveRowCount: Int
        let workoutCount: Int
        let setCount: Int
        let insertedRowCount: Int
        let enrichedRowCount: Int
    }

    enum RestoreMode {
        case emptyOrMatching
        /// The caller has independently confirmed ownership of both archive and destination.
        case mergeAfterOwnershipVerification
    }

    // The Drive file is only its magic, version and three finite choice codes. No arbitrary payload is representable.
    private static let driveMagic = Data("DUNE-DRIVE-PREFERENCES".utf8)
    private static let driveVersion: UInt8 = 1

    private struct DriveChoice {
        let defaultsKey: String
        let values: [String]

        func selectedCode(in defaults: UserDefaults) throws -> UInt8 {
            guard let stored = defaults.object(forKey: defaultsKey) else { return 0 }
            guard let raw = stored as? String else { throw Failure.invalidArchive }
            let name = defaultsKey == AppTheme.storageKey ? AppTheme.normalizedRawValue(fromPersistedRawValue: raw) : raw
            guard let name, let index = values.firstIndex(of: name) else { throw Failure.invalidArchive }
            return UInt8(index + 1)
        }
    }

    // Positions are part of the v1 file format. Zero means the user made no explicit selection.
    private static let driveChoices = [
        DriveChoice(defaultsKey: AppTheme.storageKey, values: [
            AppTheme.desertWarm, .oceanCool, .forestGreen, .sakuraCalm, .arcticDawn, .solarPop,
            .contourAtlas, .waterLilies, .patisserie,
        ].map(\.rawValue)),
        DriveChoice(defaultsKey: AppIconStyle.storageKey, values: [AppIconStyle.interleave, .ocean, .flow].map(\.rawValue)),
        DriveChoice(defaultsKey: Settings.unitKey, values: [WeightUnit.kg, .lb].map(\.rawValue)),
    ]

    static func encodeDriveSettings(defaults: UserDefaults) throws -> Data {
        var file = driveMagic
        file.append(driveVersion)
        for choice in driveChoices { file.append(try choice.selectedCode(in: defaults)) }
        return file
    }

    /// Returns false for other archive types. A recognized invalid file throws before any preference is written.
    static func restoreDriveSettingsIfPresent(_ bytes: Data, defaults: UserDefaults) throws -> Bool {
        guard bytes.starts(with: driveMagic) else { return false }
        let payload = bytes.dropFirst(driveMagic.count)
        guard let version = payload.first else { throw Failure.invalidArchive }
        guard version == driveVersion else { throw Failure.unsupportedVersion }
        guard payload.count == 1 + driveChoices.count else { throw Failure.invalidArchive }
        var updates = [String: String]()
        for (choice, code) in zip(driveChoices, payload.dropFirst()) {
            guard Int(code) <= choice.values.count else { throw Failure.invalidArchive }
            guard code != 0 else { continue }
            let local = try choice.selectedCode(in: defaults)
            guard local == 0 || local == code else { throw Failure.destinationConflict }
            if local == 0 { updates[choice.defaultsKey] = choice.values[Int(code) - 1] }
        }
        for (key, value) in updates { defaults.set(value, forKey: key) }
        return true
    }

    private struct Archive: Codable {
        let version: Int
        let tables: [String: [Row]]
        let preferences: Preferences
    }

    private struct Row: Codable, Equatable {
        let identity: String
        let parent: UUID?
        let fields: [String: Data]
    }

    // Each field is explicitly assigned its on-disk name, Swift type and writable model property.
    private struct Field<M> {
        let name: String
        let capture: (M) throws -> Data
        let restore: (M, Data) throws -> Void
        let cloudValue: (CKRecord) throws -> Data?
        let absentOptional: Data?
        let cloudDate: Bool

        init<V: Codable>(_ name: String, _ path: ReferenceWritableKeyPath<M, V>) {
            self.name = name
            cloudValue = { record in try LegacyCloud.scalar(record, name: name, type: V.self) }
            cloudDate = V.self == Date.self || V.self == Date?.self
            absentOptional = V.self is any LegacyCloudOptional.Type ? Data("null".utf8) : nil
            capture = { model in
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                return try encoder.encode(model[keyPath: path])
            }
            restore = { model, data in model[keyPath: path] = try JSONDecoder().decode(V.self, from: data) }
        }

        // Keep photos and binary attachments in binary form, distinguishing nil from zero bytes.
        init(_ name: String, _ path: ReferenceWritableKeyPath<M, Data?>) {
            self.name = name
            cloudDate = false
            absentOptional = Data([0])
            cloudValue = { record in
                try LegacyCloud.binary(record, name: name, limit: LegacyCloud.photoLimit).map { Data([1]) + $0 }
            }
            capture = { model in
                guard let bytes = model[keyPath: path] else { return Data([0]) }
                return Data([1]) + bytes
            }
            restore = { model, data in
                guard let tag = data.first else { throw Failure.invalidArchive }
                switch tag {
                case 0 where data.count == 1: model[keyPath: path] = nil
                case 1: model[keyPath: path] = Data(data.dropFirst())
                default: throw Failure.invalidArchive
                }
            }
        }
    }

    private struct Table {
        let name: String
        let capture: (ModelContext) throws -> [Row]
        let stage: ([Row], ModelContext, inout Parents) throws -> Void
        let importCloud: ([CKRecord], ModelContext, [CKRecord.ID: UUID], inout Parents) throws -> Int

        init<M: PersistentModel>(_ name: String, create: @escaping (Row) throws -> M,
                                 identity: @escaping (M) -> String,
                                 parent: @escaping (M) -> UUID? = { _ in nil },
                                 connect: @escaping (M, UUID?, inout Parents) throws -> Void = { _, id, _ in
                                     guard id == nil else { throw Failure.invalidArchive }
                                 }, fields: [Field<M>]) {
            self.name = name
            capture = { context in
                let models = try context.fetch(FetchDescriptor<M>())
                var seen = Set<String>()
                return try models.map { model in
                    let id = identity(model)
                    guard seen.insert(id).inserted else { throw Failure.duplicateIdentity }
                    var values = [String: Data]()
                    for field in fields { values[field.name] = try field.capture(model) }
                    return Row(identity: id, parent: parent(model), fields: values)
                }.sorted { $0.identity < $1.identity }
            }
            importCloud = { records, context, habitIDs, parents in
                let existing = try context.fetch(FetchDescriptor<M>())
                var local = [String: M]()
                for model in existing {
                    guard local.updateValue(model, forKey: identity(model)) == nil else { throw Failure.duplicateIdentity }
                }
                var seen = Set<String>()
                var inserted = 0
                let known = Set(fields.map { "CD_" + $0.name })
                for record in records {
                    try LegacyCloud.validateKeys(record, table: name, known: known)
                    let id: String
                    if name == "HourlyScoreSnapshot" {
                        guard let date = record["CD_date"] as? Date, date.timeIntervalSinceReferenceDate.isFinite else {
                            throw Failure.invalidArchive
                        }
                        id = date.timeIntervalSinceReferenceDate.bitPattern.description
                    } else { id = try LegacyCloud.identifier(record).uuidString }
                    guard seen.insert(id).inserted else { throw Failure.duplicateIdentity }
                    let existingModel = local[id]
                    let parentID = try LegacyCloud.parent(of: record, table: name, habitIDs: habitIDs)
                    var values = [String: Data]()
                    for field in fields {
                        if let data = try field.cloudValue(record) { values[field.name] = data }
                        else if existingModel == nil {
                            // Initializers may generate dates and normalize defaults for *new* user input.
                            // A missing old field must instead use its archived schema's default or nil.
                            values[field.name] = try field.absentOptional ?? LegacyCloud.declaredDefault(table: name, field: field.name)
                        }
                    }
                    let row = Row(identity: id, parent: parentID, fields: values)
                    let model = try existingModel ?? create(row)
                    if existingModel != nil, parent(model) != parentID { throw Failure.destinationConflict }
                    for field in fields {
                        guard let incoming = values[field.name] else { continue }
                        if existingModel != nil {
                            let current = try field.capture(model)
                            if try LegacyCloud.same(current, incoming, isDate: field.cloudDate) { continue }
                            // Nil remote fields were skipped above. Only fill a nil local value.
                            guard current == Data("null".utf8) || current == Data([0]) else { throw Failure.destinationConflict }
                        }
                        try field.restore(model, incoming)
                    }
                    guard identity(model) == id else { throw Failure.invalidArchive }
                    if existingModel == nil {
                        try connect(model, parentID, &parents)
                        context.insert(model)
                        inserted += 1
                    } else if let habit = model as? HabitDefinition {
                        parents.habits[habit.id] = habit
                    }
                }
                return inserted
            }
            stage = { rows, context, parents in
                var seen = Set<String>()
                for row in rows {
                    guard seen.insert(row.identity).inserted else { throw Failure.duplicateIdentity }
                    guard row.fields.count == fields.count else { throw Failure.invalidArchive }
                    let model = try create(row)
                    for field in fields {
                        guard let value = row.fields[field.name] else { throw Failure.invalidArchive }
                        try field.restore(model, value)
                    }
                    guard row.identity == identity(model) else { throw Failure.invalidArchive }
                    try connect(model, row.parent, &parents)
                    context.insert(model)
                }
            }
        }
    }

    /// The local model/table white list also defines the legacy CloudKit field types and key paths.
    private static var legacyCloudTables: [Table] {
        [bodyCompositionRecordTable, customExerciseTable, workoutTemplateTable, injuryRecordTable,
         habitDefinitionTable, habitLogTable, userCategoryTable, exerciseDefaultRecordTable, hourlyScoreSnapshotTable, postureAssessmentRecordTable]
    }

    static var legacyCloudRecordTypes: Set<String> { Set(legacyCloudTables.map { "CD_" + $0.name }) }

    /// The caller owns this context's save/rollback. No preferences or CloudKit records are written.
    static func importLegacyCloudRecords(_ records: [CKRecord], into context: ModelContext) throws -> Int {
        let types = legacyCloudRecordTypes
        let grouped = Dictionary(grouping: records.filter { types.contains($0.recordType) }, by: \.recordType)
        var ids = Set<CKRecord.ID>()
        for group in grouped.values {
            for record in group where !ids.insert(record.recordID).inserted { throw Failure.duplicateIdentity }
        }
        var habitIDs = [CKRecord.ID: UUID]()
        for habit in grouped["CD_HabitDefinition", default: []] {
            habitIDs[habit.recordID] = try LegacyCloud.identifier(habit)
        }
        var parents = Parents()
        var inserted = 0
        for table in legacyCloudTables {
            guard let rows = grouped["CD_" + table.name] else { continue }
            inserted += try table.importCloud(rows, context, habitIDs, &parents)
        }
        return inserted
    }

    private enum LegacyCloud {
        static let photoLimit = 32 * 1024 * 1024
        private static let collectionLimit = 4 * 1024 * 1024

        static func identifier(_ record: CKRecord) throws -> UUID {
            guard let raw = record["CD_id"] as? String, let id = UUID(uuidString: raw) else { throw Failure.invalidArchive }
            return id
        }

        static func parent(of record: CKRecord, table: String, habitIDs: [CKRecord.ID: UUID]) throws -> UUID? {
            guard table == "HabitLog" else { return nil }
            if let name = record["CD_habitDefinition"] as? String, name.isEmpty { throw Failure.missingParent }
            guard let id = LegacyWorkoutRecovery.parentRecordID(record, key: "CD_habitDefinition"),
                  let resolved = habitIDs[id] else { throw Failure.missingParent }
            return resolved
        }

        /// Literal attribute defaults from the released V1–V17 definitions. Missing identity,
        /// measurement, its timestamps, required catalog reference or routine entries are unrecoverable.
        static func declaredDefault(table: String, field: String) throws -> Data {
            let encoder = JSONEncoder()
            switch (table, field) {
            case ("BodyCompositionRecord", "memo"), ("InjuryRecord", "memo"), ("PostureAssessmentRecord", "memo"):
                return try encoder.encode("")
            case ("CustomExercise", "primaryMusclesRaw"), ("CustomExercise", "secondaryMusclesRaw"):
                return try encoder.encode([String]())
            case ("CustomExercise", "categoryRaw"): return try encoder.encode(ExerciseCategory.strength.rawValue)
            case ("CustomExercise", "equipmentRaw"): return try encoder.encode(Equipment.bodyweight.rawValue)
            case ("CustomExercise", "inputTypeRaw"), ("UserCategory", "defaultInputTypeRaw"):
                return try encoder.encode(ExerciseInputType.setsRepsWeight.rawValue)
            case ("CustomExercise", "metValue"): return try encoder.encode(3.5)
            case ("InjuryRecord", "severityRaw"), ("HabitDefinition", "goalValue"): return try encoder.encode(1)
            case ("HabitDefinition", "iconCategoryRaw"): return try encoder.encode("health")
            case ("HabitDefinition", "habitTypeRaw"): return try encoder.encode("check")
            case ("HabitDefinition", "frequencyTypeRaw"): return try encoder.encode("daily")
            case ("HabitDefinition", "weeklyTargetDays"): return try encoder.encode(3)
            case ("HabitDefinition", "recurringStartPointRaw"): return try encoder.encode("createdAt")
            case ("HabitDefinition", "reminderHour"): return try encoder.encode(9)
            case ("HabitDefinition", "timeOfDayRaw"): return try encoder.encode("anytime")
            case ("HabitDefinition", "isAutoLinked"), ("HabitDefinition", "isArchived"), ("HabitLog", "isAutoCompleted"),
                 ("ExerciseDefaultRecord", "isPreferred"), ("ExerciseDefaultRecord", "isManualOverride"):
                return try encoder.encode(false)
            case ("HabitDefinition", "reminderMinute"), ("HabitDefinition", "sortOrder"), ("UserCategory", "sortOrder"),
                 ("PostureAssessmentRecord", "overallScore"): return try encoder.encode(0)
            case ("UserCategory", "iconName"): return try encoder.encode("tag.fill")
            case ("UserCategory", "colorHex"): return try encoder.encode("007AFF")
            case ("PostureAssessmentRecord", "frontMetricsJSON"), ("PostureAssessmentRecord", "sideMetricsJSON"),
                 ("PostureAssessmentRecord", "frontJointPositionsJSON"), ("PostureAssessmentRecord", "sideJointPositionsJSON"):
                return try encoder.encode("[]")
            case ("PostureAssessmentRecord", "heightEstimationRaw"): return try encoder.encode(HeightEstimationType.reference.rawValue)
            default: throw Failure.invalidArchive
            }
        }

        static func validateKeys(_ record: CKRecord, table: String, known: Set<String>) throws {
            for key in record.allKeys() where key.hasPrefix("CD_") {
                if key == "CD_entityName" || (table == "HabitLog" && key == "CD_habitDefinition") { continue }
                let base = key.hasSuffix("_ckAsset") ? String(key.dropLast("_ckAsset".count)) : key
                guard known.contains(base) else { throw Failure.invalidArchive }
            }
        }

        static func same(_ local: Data, _ remote: Data, isDate: Bool) throws -> Bool {
            if local == remote { return true }
            guard isDate, let lhs = try JSONDecoder().decode(Date?.self, from: local),
                  let rhs = try JSONDecoder().decode(Date?.self, from: remote) else { return false }
            // CloudKit's transport can round existing submillisecond times.
            return abs(lhs.timeIntervalSince(rhs)) < 0.0011
        }

        static func binary(_ record: CKRecord, name: String, limit: Int) throws -> Data? {
            let key = "CD_" + name
            let inline = record[key], external = record[key + "_ckAsset"]
            guard inline != nil || external != nil else { return nil }
            guard inline == nil || external == nil else { throw Failure.invalidArchive }
            if let data = inline as? Data {
                guard data.count <= limit else { throw Failure.invalidArchive }
                return data
            }
            guard let asset = (external ?? inline) as? CKAsset, let url = asset.fileURL else { throw Failure.invalidArchive }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }
            let size = try file.seekToEnd()
            guard size <= UInt64(limit) else { throw Failure.invalidArchive }
            try file.seek(toOffset: 0)
            var bytes = Data()
            while let chunk = try file.read(upToCount: min(1_048_576, limit - bytes.count + 1)), !chunk.isEmpty {
                bytes.append(chunk)
                guard bytes.count <= limit else { throw Failure.invalidArchive }
            }
            guard bytes.count == Int(size) else { throw Failure.invalidArchive }
            return bytes
        }

        static func scalar<V: Codable>(_ record: CKRecord, name: String, type: V.Type) throws -> Data? {
            let key = "CD_" + name
            let raw = record[key], external = record[key + "_ckAsset"]
            guard raw != nil || external != nil else { return nil }
            guard raw == nil || external == nil else { throw Failure.invalidArchive }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            if type == [String].self {
                if let strings = raw as? [String] { return try encoder.encode(strings) }
                guard let bytes = try binary(record, name: name, limit: collectionLimit) else { throw Failure.invalidArchive }
                return try encoder.encode(collection([String].self, bytes: bytes))
            }
            if type == [TemplateEntry].self {
                guard let bytes = try binary(record, name: name, limit: collectionLimit) else { throw Failure.invalidArchive }
                return try encoder.encode(collection([TemplateEntry].self, bytes: bytes))
            }
            if type == String.self || type == String?.self {
                if let value = raw as? String { return try encoder.encode(value) }
                if raw is CKAsset || external != nil, let data = try binary(record, name: name, limit: collectionLimit),
                   let value = String(data: data, encoding: .utf8) { return try encoder.encode(value) }
                throw Failure.invalidArchive
            }
            guard external == nil else { throw Failure.invalidArchive }
            if type == UUID.self { return try encoder.encode(identifier(record)) }
            if type == Date.self || type == Date?.self, let value = raw as? Date { return try encoder.encode(value) }
            guard let number = raw as? NSNumber else { throw Failure.invalidArchive }
            if type == Bool.self || type == Bool?.self {
                guard number.compare(0) == .orderedSame || number.compare(1) == .orderedSame else { throw Failure.invalidArchive }
                return try encoder.encode(number.boolValue)
            }
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { throw Failure.invalidArchive }
            if type == Int.self || type == Int?.self, number.compare(NSNumber(value: number.intValue)) == .orderedSame {
                return try encoder.encode(number.intValue)
            }
            if type == Double.self || type == Double?.self, number.doubleValue.isFinite {
                return try encoder.encode(number.doubleValue)
            }
            throw Failure.invalidArchive
        }

        private static func collection<T: Decodable>(_ type: T.Type, bytes: Data) throws -> T {
            if let json = try? JSONDecoder().decode(type, from: bytes) { return json }
            if let plist = try? PropertyListDecoder().decode(type, from: bytes) { return plist }
            // NSPersistentCloudKitContainer may wrap a transformable in an NSSecureCoding archive.
            guard let plist = try? PropertyListSerialization.propertyList(from: bytes, format: nil) as? [String: Any],
                  plist["$archiver"] as? String == "NSKeyedArchiver" else { throw Failure.invalidArchive }
            let allowed: [AnyClass] = [NSArray.self, NSDictionary.self, NSString.self, NSNumber.self, NSDate.self,
                                       NSData.self, NSUUID.self, NSNull.self]
            let root = try NSKeyedUnarchiver.unarchivedObject(ofClasses: allowed, from: bytes)
            if let data = root as? Data {
                if let decoded = try? JSONDecoder().decode(type, from: data) { return decoded }
                return try PropertyListDecoder().decode(type, from: data)
            }
            guard let root, JSONSerialization.isValidJSONObject(root) else { throw Failure.invalidArchive }
            let json = try JSONSerialization.data(withJSONObject: root)
            return try JSONDecoder().decode(type, from: json)
        }
    }

    private struct Parents {
        var exercises: [UUID: ExerciseRecord] = [:]
        var habits: [UUID: HabitDefinition] = [:]
    }

    private static let tables: [Table] = [
        exerciseRecordTable, workoutSetTable, bodyCompositionRecordTable,
        customExerciseTable, workoutTemplateTable, injuryRecordTable,
        habitDefinitionTable, habitLogTable, userCategoryTable,
        exerciseDefaultRecordTable, hourlyScoreSnapshotTable, postureAssessmentRecordTable,
        workoutLocationRecordTable,
    ]

    private static let exerciseRecordTable = Table("ExerciseRecord", create: { _ in ExerciseRecord() },
      identity: { $0.id.uuidString },
      connect: { model, parent, refs in
          guard parent == nil else { throw Failure.invalidArchive }
          refs.exercises[model.id] = model
      }, fields: [
          .init("id", \.id),
          .init("date", \.date),
          .init("exerciseType", \.exerciseType),
          .init("duration", \.duration),
          .init("calories", \.calories),
          .init("distance", \.distance),
          .init("stepCount", \.stepCount),
          .init("averagePaceSecondsPerKm", \.averagePaceSecondsPerKm),
          .init("averageCadenceStepsPerMinute", \.averageCadenceStepsPerMinute),
          .init("elevationGainMeters", \.elevationGainMeters),
          .init("floorsAscended", \.floorsAscended),
          .init("cardioMachineLevelAverage", \.cardioMachineLevelAverage),
          .init("cardioMachineLevelMax", \.cardioMachineLevelMax),
          .init("cardioMachineLevelChangesData", \.cardioMachineLevelChangesData),
          .init("memo", \.memo),
          .init("isFromHealthKit", \.isFromHealthKit),
          .init("healthKitWorkoutID", \.healthKitWorkoutID),
          .init("createdAt", \.createdAt),
          .init("exerciseDefinitionID", \.exerciseDefinitionID),
          .init("primaryMusclesRaw", \.primaryMusclesRaw),
          .init("secondaryMusclesRaw", \.secondaryMusclesRaw),
          .init("equipmentRaw", \.equipmentRaw),
          .init("estimatedCalories", \.estimatedCalories),
          .init("calorieSourceRaw", \.calorieSourceRaw),
          .init("rpe", \.rpe),
          .init("autoIntensityRaw", \.autoIntensityRaw),
          .init("cardioFitnessVO2Max", \.cardioFitnessVO2Max),
          .init("plannedSetCount", \.plannedSetCount),
          .init("effortSourceRaw", \.effortSourceRaw),
      ])

    private static let workoutSetTable = Table("WorkoutSet", create: { _ in WorkoutSet() },
      identity: { $0.id.uuidString }, parent: { $0.exerciseRecord?.id },
      connect: { model, parent, refs in
          guard let parent, let workout = refs.exercises[parent] else { throw Failure.missingParent }
          model.exerciseRecord = workout
      }, fields: [
          .init("id", \.id),
          .init("setNumber", \.setNumber),
          .init("setTypeRaw", \.setTypeRaw),
          .init("weight", \.weight),
          .init("reps", \.reps),
          .init("duration", \.duration),
          .init("distance", \.distance),
          .init("intensity", \.intensity),
          .init("isCompleted", \.isCompleted),
          .init("restDuration", \.restDuration),
          .init("rpe", \.rpe),
          .init("plannedReps", \.plannedReps),
          .init("rpeSourceRaw", \.rpeSourceRaw),
      ])

    private static let bodyCompositionRecordTable = Table("BodyCompositionRecord", create: { _ in BodyCompositionRecord() },
      identity: { $0.id.uuidString }, fields: [
          .init("id", \.id),
          .init("date", \.date),
          .init("weight", \.weight),
          .init("bodyFatPercentage", \.bodyFatPercentage),
          .init("muscleMass", \.muscleMass),
          .init("memo", \.memo),
          .init("createdAt", \.createdAt),
      ])

    private static let customExerciseTable = Table("CustomExercise", create: { _ in CustomExercise(name: "", category: .strength, inputType: .setsRepsWeight, primaryMuscles: [], equipment: .bodyweight) },
      identity: { $0.id.uuidString }, fields: [
          .init("id", \.id),
          .init("name", \.name),
          .init("categoryRaw", \.categoryRaw),
          .init("inputTypeRaw", \.inputTypeRaw),
          .init("primaryMusclesRaw", \.primaryMusclesRaw),
          .init("secondaryMusclesRaw", \.secondaryMusclesRaw),
          .init("equipmentRaw", \.equipmentRaw),
          .init("metValue", \.metValue),
          .init("customCategoryName", \.customCategoryName),
          .init("cardioSecondaryUnitRaw", \.cardioSecondaryUnitRaw),
          .init("createdAt", \.createdAt),
      ])

    private static let workoutTemplateTable = Table("WorkoutTemplate", create: { _ in WorkoutTemplate(name: "") },
      identity: { $0.id.uuidString }, fields: [
          .init("id", \.id),
          .init("name", \.name),
          .init("exerciseEntries", \.exerciseEntries),
          .init("createdAt", \.createdAt),
          .init("updatedAt", \.updatedAt),
      ])

    private static let injuryRecordTable = Table("InjuryRecord", create: { _ in InjuryRecord(bodyPart: .neck, bodySide: nil, severity: .minor, startDate: .distantPast) },
      identity: { $0.id.uuidString }, fields: [
          .init("id", \.id),
          .init("bodyPartRaw", \.bodyPartRaw),
          .init("bodySideRaw", \.bodySideRaw),
          .init("severityRaw", \.severityRaw),
          .init("startDate", \.startDate),
          .init("endDate", \.endDate),
          .init("memo", \.memo),
          .init("createdAt", \.createdAt),
      ])

    private static let habitDefinitionTable = Table("HabitDefinition", create: { _ in HabitDefinition(name: "", iconCategory: .health, habitType: .check, goalValue: 1, goalUnit: nil, frequency: .daily) },
      identity: { $0.id.uuidString },
      connect: { model, parent, refs in
          guard parent == nil else { throw Failure.invalidArchive }
          refs.habits[model.id] = model
      }, fields: [
          .init("id", \.id),
          .init("name", \.name),
          .init("iconCategoryRaw", \.iconCategoryRaw),
          .init("habitTypeRaw", \.habitTypeRaw),
          .init("goalValue", \.goalValue),
          .init("goalUnit", \.goalUnit),
          .init("frequencyTypeRaw", \.frequencyTypeRaw),
          .init("weeklyTargetDays", \.weeklyTargetDays),
          .init("recurringStartPointRaw", \.recurringStartPointRaw),
          .init("recurringCustomStartDate", \.recurringCustomStartDate),
          .init("recurringStartConfiguredAt", \.recurringStartConfiguredAt),
          .init("isAutoLinked", \.isAutoLinked),
          .init("autoLinkSourceRaw", \.autoLinkSourceRaw),
          .init("sortOrder", \.sortOrder),
          .init("isArchived", \.isArchived),
          .init("createdAt", \.createdAt),
          .init("reminderHour", \.reminderHour),
          .init("reminderMinute", \.reminderMinute),
          .init("timeOfDayRaw", \.timeOfDayRaw),
      ])

    private static let habitLogTable = Table("HabitLog", create: { _ in HabitLog(date: .distantPast, value: 0) },
      identity: { $0.id.uuidString }, parent: { $0.habitDefinition?.id },
      connect: { model, parent, refs in
          guard let parent, let habit = refs.habits[parent] else { throw Failure.missingParent }
          model.habitDefinition = habit
      }, fields: [
          .init("id", \.id),
          .init("date", \.date),
          .init("value", \.value),
          .init("isAutoCompleted", \.isAutoCompleted),
          .init("completedAt", \.completedAt),
          .init("memo", \.memo),
      ])

    private static let userCategoryTable = Table("UserCategory", create: { _ in UserCategory(name: "") },
      identity: { $0.id.uuidString }, fields: [
          .init("id", \.id),
          .init("name", \.name),
          .init("iconName", \.iconName),
          .init("colorHex", \.colorHex),
          .init("defaultInputTypeRaw", \.defaultInputTypeRaw),
          .init("sortOrder", \.sortOrder),
          .init("createdAt", \.createdAt),
      ])

    private static let exerciseDefaultRecordTable = Table("ExerciseDefaultRecord", create: { row in
        try ExerciseDefaultRecord(exerciseDefinitionID: defaultDefinitionID(in: row))
    },
      identity: { $0.id.uuidString }, fields: [
          .init("id", \.id),
          .init("exerciseDefinitionID", \.exerciseDefinitionID),
          .init("defaultWeight", \.defaultWeight),
          .init("defaultReps", \.defaultReps),
          .init("isManualOverride", \.isManualOverride),
          .init("isPreferred", \.isPreferred),
          .init("lastUsedDate", \.lastUsedDate),
      ])

    private static let hourlyScoreSnapshotTable = Table("HourlyScoreSnapshot", create: { _ in HourlyScoreSnapshot(date: .distantPast) },
      identity: { $0.date.timeIntervalSinceReferenceDate.bitPattern.description }, fields: [
          .init("date", \.date),
          .init("conditionScore", \.conditionScore),
          .init("wellnessScore", \.wellnessScore),
          .init("readinessScore", \.readinessScore),
          .init("hrvValue", \.hrvValue),
          .init("rhrValue", \.rhrValue),
          .init("sleepScore", \.sleepScore),
          .init("stressScore", \.stressScore),
          .init("createdAt", \.createdAt),
      ])

    private static let postureAssessmentRecordTable = Table("PostureAssessmentRecord", create: { _ in PostureAssessmentRecord() },
      identity: { $0.id.uuidString }, fields: [
          .init("id", \.id),
          .init("date", \.date),
          .init("overallScore", \.overallScore),
          .init("frontMetricsJSON", \.frontMetricsJSON),
          .init("sideMetricsJSON", \.sideMetricsJSON),
          .init("frontJointPositionsJSON", \.frontJointPositionsJSON),
          .init("sideJointPositionsJSON", \.sideJointPositionsJSON),
          .init("frontImageData", \.frontImageData),
          .init("sideImageData", \.sideImageData),
          .init("bodyHeight", \.bodyHeight),
          .init("heightEstimationRaw", \.heightEstimationRaw),
          .init("memo", \.memo),
          .init("createdAt", \.createdAt),
      ])

    private static let workoutLocationRecordTable = Table("WorkoutLocationRecord", create: { _ in WorkoutLocationRecord(payload: WorkoutLocationPayload()) },
      identity: { $0.id.uuidString },
      connect: { model, parent, refs in
          guard parent == nil else { throw Failure.invalidArchive }
          if let local = model.localRecordID, refs.exercises[local] == nil { throw Failure.missingParent }
          guard model.localRecordID != nil || model.healthKitWorkoutID?.isEmpty == false else { throw Failure.missingParent }
      }, fields: [
          .init("id", \.id),
          .init("localRecordID", \.localRecordID),
          .init("healthKitWorkoutID", \.healthKitWorkoutID),
          .init("payloadData", \.payloadData),
          .init("updatedAt", \.updatedAt),
      ])

    /// Only portable choices; permissions, sync consent, account identifiers and credentials are device-local.
    private struct Settings: Codable, Equatable {
        var theme: AppTheme?
        var icon: AppIconStyle?
        var weightUnit: String?
        var restSeconds: Double?
        var setCount: Int?
        var manualBodyWeightKg: Double?

        // The UI's WeightUnit.storageKey is presentation-only. The round-trip test uses that public key.
        fileprivate static let unitKey = "com.raftel.dailve.weightUnit"
        private static func workoutKey(_ suffix: String) -> String { Preferences.prefix + ".settings." + suffix }

        init() {}

        init(_ defaults: UserDefaults) throws {
            func text(_ key: String) throws -> String? {
                guard let stored = defaults.object(forKey: key) else { return nil }
                guard let value = stored as? String else { throw Failure.invalidArchive }
                return value
            }
            func number(_ suffix: String) throws -> Double? {
                guard let stored = defaults.object(forKey: Self.workoutKey(suffix)) else { return nil }
                guard let value = stored as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
                      value.doubleValue.isFinite else { throw Failure.invalidArchive }
                return value.doubleValue
            }
            if let value = try text(AppTheme.storageKey) {
                guard let resolved = AppTheme.resolvedTheme(fromPersistedRawValue: value) else { throw Failure.invalidArchive }
                theme = resolved
            }
            if let value = try text(AppIconStyle.storageKey) {
                guard let resolved = AppIconStyle(rawValue: value) else { throw Failure.invalidArchive }
                icon = resolved
            }
            weightUnit = try text(Self.unitKey)
            restSeconds = try number("restSeconds")
            if let value = try number("setCount") {
                guard let count = Int(exactly: value) else { throw Failure.invalidArchive }
                setCount = count
            }
            manualBodyWeightKg = try number("bodyWeightKg")
            try validate()
        }

        func validate() throws {
            guard weightUnit.map({ WeightUnit(rawValue: $0) != nil }) ?? true,
                  restSeconds.map(WorkoutSettingsStore.restSecondsRange.contains) ?? true,
                  setCount.map(WorkoutSettingsStore.setCountRange.contains) ?? true,
                  manualBodyWeightKg.map(WorkoutSettingsStore.bodyWeightRange.contains) ?? true else {
                throw Failure.invalidArchive
            }
        }

        func merging(_ local: Self) throws -> Self {
            func combine<T: Equatable>(_ incoming: T?, _ current: T?) throws -> T? {
                if let incoming, let current, incoming != current { throw Failure.destinationConflict }
                return incoming ?? current
            }
            var result = self
            result.theme = try combine(theme, local.theme)
            result.icon = try combine(icon, local.icon)
            result.weightUnit = try combine(weightUnit, local.weightUnit)
            result.restSeconds = try combine(restSeconds, local.restSeconds)
            result.setCount = try combine(setCount, local.setCount)
            result.manualBodyWeightKg = try combine(manualBodyWeightKg, local.manualBodyWeightKg)
            return result
        }

        func install(into defaults: UserDefaults) {
            if let theme { defaults.set(theme.rawValue, forKey: AppTheme.storageKey) }
            if let icon { defaults.set(icon.rawValue, forKey: AppIconStyle.storageKey) }
            if let weightUnit { defaults.set(weightUnit, forKey: Self.unitKey) }
            if let restSeconds { defaults.set(restSeconds, forKey: Self.workoutKey("restSeconds")) }
            if let setCount { defaults.set(setCount, forKey: Self.workoutKey("setCount")) }
            if let manualBodyWeightKg { defaults.set(manualBodyWeightKg, forKey: Self.workoutKey("bodyWeightKg")) }
        }
    }

    private struct Preferences: Codable, Equatable {
        // Keys in the archive are portable activity names, never arbitrary defaults keys.
        var rewards: Data?
        var records: [String: Data]
        var titles: [String: String]?
        var settings: Settings?

        private static let titleKey = "workout.type.corrections.v1"
        fileprivate static var prefix: String { Bundle.main.bundleIdentifier ?? "com.dailve" }
        private static var rewardKey: String { prefix + ".workoutRewards.state" }
        private static func recordKey(_ activity: String) -> String { prefix + ".personalRecords." + activity }

        init(_ defaults: UserDefaults) throws {
            func bytes(_ key: String) throws -> Data? {
                guard let value = defaults.object(forKey: key) else { return nil }
                guard let data = value as? Data else { throw Failure.invalidArchive }
                return data
            }
            let selected = try Settings(defaults)
            settings = selected == Settings() ? nil : selected
            rewards = try bytes(Self.rewardKey)
            records = [:]
            for activity in WorkoutActivityType.allCases {
                records[activity.rawValue] = try bytes(Self.recordKey(activity.rawValue))
            }
            if let value = defaults.object(forKey: Self.titleKey) {
                guard let map = value as? [String: String] else { throw Failure.invalidArchive }
                titles = map
            }
            try validate()
        }

        // PersonalRecordStore persists a non-String-key dictionary as alternating key/value elements.
        // Dictionary decoding alone would silently accept a duplicate key in a malformed archive.
        private struct RecordValues: Decodable {
            var values = [PersonalRecordType: PersonalRecord]()

            init(from decoder: Decoder) throws {
                var pairs = try decoder.unkeyedContainer()
                while !pairs.isAtEnd {
                    let type = try pairs.decode(PersonalRecordType.self)
                    let value = try pairs.decode(PersonalRecord.self)
                    guard value.type == type, values.updateValue(value, forKey: type) == nil else {
                        throw Failure.invalidArchive
                    }
                }
            }
        }

        // The persisted layout comes from PersonalRecordStore.RewardState.
        private struct RewardValue: Decodable {
            let milestoneTierByActivity: [String: Int]
            let unlockedBadges: [String]
            let totalPoints: Int
            let level: Int
            let history: [WorkoutRewardEvent]
            let processedWorkoutSignatures: [String: String]

            func recordedPoints() throws -> Int {
                var points = 0
                for event in history {
                    let next = points.addingReportingOverflow(event.pointsAwarded)
                    guard !next.overflow, event.pointsAwarded >= 0 else { throw Failure.invalidArchive }
                    points = next.partialValue
                }
                return points
            }

            func validate() throws {
                guard level >= 1, totalPoints >= 0, try recordedPoints() <= totalPoints,
                      milestoneTierByActivity.values.allSatisfy({ $0 >= 0 }),
                      Set(unlockedBadges).count == unlockedBadges.count,
                      Set(history.map(\.id)).count == history.count,
                      history.allSatisfy({ !$0.id.isEmpty && !$0.workoutID.isEmpty })
                else { throw Failure.invalidArchive }
            }

            private func coversSignatures(_ other: Self) -> Bool {
                for (workoutID, oldValue) in other.processedWorkoutSignatures {
                    guard let value = processedWorkoutSignatures[workoutID] else { return false }
                    if value == oldValue { continue }
                    guard let file = PersonalRecordStore.RewardSignature(value),
                          let local = PersonalRecordStore.RewardSignature(oldValue),
                          file.activity == local.activity, file.milestone == local.milestone else { return false }
                    func earned(in events: [WorkoutRewardEvent]) -> Set<PersonalRecordType> {
                        var types = Set<PersonalRecordType>()
                        for event in events where event.workoutID == workoutID && event.activityTypeRawValue == file.activity {
                            types.formUnion(PersonalRecordStore.creditedTypes(in: event))
                        }
                        return types
                    }
                    let fileEarned = earned(in: history)
                    guard file.credited.symmetricDifference(local.credited).isSubset(of: fileEarned),
                          local.credited.union(earned(in: other.history)).isSubset(of: file.credited.union(fileEarned))
                    else { return false }
                }
                return true
            }

            func covers(_ other: Self) throws -> Bool {
                let badges = Set(unlockedBadges), otherBadges = Set(other.unlockedBadges)
                let receipts = Set(history), otherReceipts = Set(other.history)
                guard otherBadges.isSubset(of: badges), otherReceipts.isSubset(of: receipts),
                      coversSignatures(other),
                      other.milestoneTierByActivity.allSatisfy({ (milestoneTierByActivity[$0.key] ?? -1) >= $0.value }),
                      totalPoints >= other.totalPoints, level >= other.level else { return false }
                if receipts == otherReceipts, badges == otherBadges, totalPoints == other.totalPoints,
                   level == other.level, milestoneTierByActivity == other.milestoneTierByActivity,
                   processedWorkoutSignatures.keys == other.processedWorkoutSignatures.keys {
                    return true
                }
                // Older/capped ledgers can be equivalent, but an incomplete local ledger cannot prove
                // that all of its points belong to the matching workouts. Never add two totals together.
                guard other.unlockedBadges.isEmpty || !other.history.isEmpty,
                      try other.recordedPoints() == other.totalPoints,
                      other.history.allSatisfy({ other.processedWorkoutSignatures[$0.workoutID] != nil }) else {
                    return false
                }
                for (activity, tier) in other.milestoneTierByActivity where tier > 0 {
                    guard other.history.contains(where: {
                        $0.kind == .milestone && $0.activityTypeRawValue == activity && $0.id.hasSuffix("-tier-" + String(tier))
                    }) else { return false }
                }
                return other.level == 1 || other.history.contains { $0.kind == .levelUp && $0.levelAfterEvent == other.level }
            }
        }

        // Codable accepts duplicate object members by selecting one. After typed decoding has
        // checked JSON syntax, reject repeated names (including escaped equivalents) at any depth.
        private func rejectDuplicateJSONMembers(in data: Data) throws {
            var scopes = [Set<String>]()
            var cursor = data.startIndex
            while cursor < data.endIndex {
                let token = data[cursor]
                cursor += 1
                switch token {
                case 123: scopes.append([]) // {
                case 125: _ = scopes.popLast() // }
                case 34: // Skip an entire JSON string, including escaped quotation marks.
                    let start = cursor - 1
                    var escaped = false
                    while cursor < data.endIndex {
                        let byte = data[cursor]
                        cursor += 1
                        if byte == 34 { break }
                        if byte == 92 {
                            escaped = true
                            guard cursor < data.endIndex else { throw Failure.invalidArchive }
                            cursor += 1
                        }
                    }
                    let end = cursor
                    while cursor < data.endIndex && [9, 10, 13, 32].contains(data[cursor]) { cursor += 1 }
                    guard cursor < data.endIndex, data[cursor] == 58, !scopes.isEmpty else { continue }
                    let key = escaped ? try JSONDecoder().decode(String.self, from: data[start..<end])
                        : String(decoding: data[(start + 1)..<(end - 1)], as: UTF8.self)
                    guard scopes[scopes.count - 1].insert(key).inserted else { throw Failure.invalidArchive }
                default: break
                }
            }
        }

        func validate() throws {
            try settings?.validate()
            if let rewards {
                try JSONDecoder().decode(RewardValue.self, from: rewards).validate()
                try rejectDuplicateJSONMembers(in: rewards)
            }
            for (key, data) in records {
                guard WorkoutActivityType(rawValue: key) != nil else { throw Failure.invalidArchive }
                _ = try JSONDecoder().decode(RecordValues.self, from: data)
                try rejectDuplicateJSONMembers(in: data)
            }
        }

        private func resolvedRewards(_ local: Data?, allowLocalOnly: Bool) throws -> Data? {
            guard let local else { return rewards }
            guard let rewards else {
                guard allowLocalOnly else { throw Failure.destinationConflict }
                return local
            }
            let fileState = try JSONDecoder().decode(RewardValue.self, from: rewards)
            let localState = try JSONDecoder().decode(RewardValue.self, from: local)
            if try fileState.covers(localState) { return rewards }
            if allowLocalOnly, try localState.covers(fileState) { return local }
            throw Failure.destinationConflict
        }

        private func resolvedRecords(_ local: [String: Data], allowLocalOnly: Bool) throws -> [String: Data] {
            var result = records
            for (activity, localBytes) in local {
                guard let fileBytes = records[activity] else {
                    guard allowLocalOnly else { throw Failure.destinationConflict }
                    result[activity] = localBytes
                    continue
                }
                let fileValues = try JSONDecoder().decode(RecordValues.self, from: fileBytes).values
                let localValues = try JSONDecoder().decode(RecordValues.self, from: localBytes).values
                var combined = fileValues
                for (type, value) in localValues {
                    if let archived = fileValues[type] {
                        guard let enriched = archived.supplementingContext(from: value),
                              allowLocalOnly || enriched == archived else { throw Failure.destinationConflict }
                        combined[type] = enriched
                    } else {
                        guard allowLocalOnly else { throw Failure.destinationConflict }
                        combined[type] = value
                    }
                }
                if combined != fileValues {
                    result[activity] = combined == localValues ? localBytes : try JSONEncoder().encode(combined)
                }
            }
            return result
        }

        func contains(_ existing: Self) throws -> Bool {
            let selected = settings ?? Settings()
            _ = try resolvedRecords(existing.records, allowLocalOnly: false)
            _ = try resolvedRewards(existing.rewards, allowLocalOnly: false)
            return try selected.merging(existing.settings ?? Settings()) == selected
                && (existing.titles == nil || existing.titles == titles)
        }

        func merged(with local: Self) throws -> Self {
            var result = self
            let selected = try (settings ?? Settings()).merging(local.settings ?? Settings())
            result.settings = selected == Settings() ? nil : selected
            result.rewards = try resolvedRewards(local.rewards, allowLocalOnly: true)
            result.records = try resolvedRecords(local.records, allowLocalOnly: true)
            if local.titles != nil || titles != nil {
                result.titles = try (local.titles ?? [:]).merging(titles ?? [:]) { a, b in
                    guard a == b else { throw Failure.destinationConflict }
                    return a
                }
            }
            return result
        }

        func install(into defaults: UserDefaults) {
            settings?.install(into: defaults)
            if let rewards { defaults.set(rewards, forKey: Self.rewardKey) }
            if let titles { defaults.set(titles, forKey: Self.titleKey) }
            for (activity, data) in records { defaults.set(data, forKey: Self.recordKey(activity)) }
        }
    }

    private static func snapshot(_ context: ModelContext) throws -> [String: [Row]] {
        var result = [String: [Row]]()
        for table in tables { result[table.name] = try table.capture(context) }
        try validateReferences(result)
        return result
    }

    private static func defaultDefinitionID(in row: Row) throws -> String {
        guard let bytes = row.fields["exerciseDefinitionID"] else { throw Failure.invalidArchive }
        let identifier = try JSONDecoder().decode(String.self, from: bytes)
        guard !identifier.isEmpty else { throw Failure.invalidArchive }
        return identifier
    }

    private static func validateReferences(_ result: [String: [Row]]) throws {
        for row in result["ExerciseDefaultRecord", default: []] { _ = try defaultDefinitionID(in: row) }
        // Each archive is self-contained, even when the destination already has additional rows.
        let workouts = Set(result["ExerciseRecord", default: []].map(\.identity))
        let habits = Set(result["HabitDefinition", default: []].map(\.identity))
        for (table, parents) in [("WorkoutSet", workouts), ("HabitLog", habits)] {
            for row in result[table, default: []] {
                guard let parent = row.parent, parents.contains(parent.uuidString) else { throw Failure.missingParent }
            }
        }
        for row in result["WorkoutLocationRecord", default: []] {
            let decoder = JSONDecoder()
            let local = try decoder.decode(UUID?.self, from: row.fields["localRecordID"] ?? Data())
            let health = try decoder.decode(String?.self, from: row.fields["healthKitWorkoutID"] ?? Data())
            guard local.map({ workouts.contains($0.uuidString) }) ?? (health?.isEmpty == false) else {
                throw Failure.missingParent
            }
        }
    }

    static func encode(from context: ModelContext, defaults: UserDefaults) throws -> Data {
        guard !context.hasChanges else { throw Failure.unsavedChanges }
        let rows = try snapshot(context)
        let preferences = try PersonalRecordStore.withMutationLock { try Preferences(defaults) }
        let archive = Archive(version: 1, tables: rows, preferences: preferences)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let bytes = try encoder.encode(archive)
        guard bytes.count <= EncryptedRecoveryArchive.maximumPlaintextBytes else {
            throw EncryptedRecoveryArchive.ArchiveError.sizeLimitExceeded
        }
        return bytes
    }

    // These are the optional fields added after the original workout schema.
    private static func supplementalFields(for table: String) -> [String] {
        switch table {
        case "ExerciseRecord": ["plannedSetCount", "effortSourceRaw"]
        case "WorkoutSet": ["plannedReps", "rpeSourceRaw"]
        default: []
        }
    }

    private static func normalized(_ row: Row, supplementalFields: [String]) -> Row {
        guard supplementalFields.contains(where: { row.fields[$0] == nil }) else { return row }
        var fields = row.fields
        for key in supplementalFields where fields[key] == nil { fields[key] = Data("null".utf8) }
        return Row(identity: row.identity, parent: row.parent, fields: fields)
    }

    /// Follow legacy workout recovery semantics: nil carries no update and two different values conflict.
    private static func supplement<M: AnyObject, V: Decodable & Equatable>(
        _ key: ReferenceWritableKeyPath<M, V?>, on model: M, from row: Row, field: String
    ) throws -> Bool {
        guard let bytes = row.fields[field] else { throw Failure.invalidArchive }
        guard let incoming = try JSONDecoder().decode(V?.self, from: bytes) else { return false }
        if let local = model[keyPath: key] {
            guard local == incoming else { throw Failure.destinationConflict }
            return false
        }
        model[keyPath: key] = incoming
        return true
    }

    private static func enrich(_ current: Row, from incoming: Row, fields: [String],
                               workout: ExerciseRecord?, set: WorkoutSet?) throws -> Bool {
        guard !fields.isEmpty, current.parent == incoming.parent,
              current.fields.keys == incoming.fields.keys,
              current.fields.allSatisfy({ fields.contains($0.key) || incoming.fields[$0.key] == $0.value }) else {
            throw Failure.destinationConflict
        }
        if let workout {
            let count = try supplement(\.plannedSetCount, on: workout, from: incoming, field: "plannedSetCount")
            let source = try supplement(\.effortSourceRaw, on: workout, from: incoming, field: "effortSourceRaw")
            return count || source
        }
        if let set {
            let reps = try supplement(\.plannedReps, on: set, from: incoming, field: "plannedReps")
            let source = try supplement(\.rpeSourceRaw, on: set, from: incoming, field: "rpeSourceRaw")
            return reps || source
        }
        throw Failure.destinationConflict
    }

    @discardableResult
    static func restore(_ data: Data, into destination: ModelContext, defaults: UserDefaults,
                        mode: RestoreMode = .emptyOrMatching) throws -> RestoreResult {
        guard data.count <= EncryptedRecoveryArchive.maximumPlaintextBytes else {
            throw EncryptedRecoveryArchive.ArchiveError.sizeLimitExceeded
        }
        guard !destination.hasChanges else { throw Failure.unsavedChanges }
        let archive = try PropertyListDecoder().decode(Archive.self, from: data)
        guard archive.version == 1 else { throw Failure.unsupportedVersion }
        guard Set(archive.tables.keys) == Set(tables.map(\.name)) else { throw Failure.invalidArchive }
        try validateReferences(archive.tables)
        try archive.preferences.validate()

        let context = ModelContext(destination.container)
        context.autosaveEnabled = false
        defer { if context.hasChanges { context.rollback() } }
        let existing = try snapshot(context)
        if mode == .emptyOrMatching, !existing.values.allSatisfy(\.isEmpty), existing != archive.tables {
            throw Failure.destinationConflict
        }

        var parents = Parents()
        for workout in try context.fetch(FetchDescriptor<ExerciseRecord>()) { parents.exercises[workout.id] = workout }
        for habit in try context.fetch(FetchDescriptor<HabitDefinition>()) { parents.habits[habit.id] = habit }
        var localSets: [UUID: WorkoutSet] = [:]
        if mode == .mergeAfterOwnershipVerification {
            for set in try context.fetch(FetchDescriptor<WorkoutSet>()) { localSets[set.id] = set }
        }
        var inserted = 0
        var enriched = 0
        for table in tables {
            guard let incoming = archive.tables[table.name], let local = existing[table.name] else {
                throw Failure.invalidArchive
            }
            var seen = Set<String>()
            var additions: [Row] = []
            let allowed = mode == .mergeAfterOwnershipVerification ? supplementalFields(for: table.name) : []
            let byID = Dictionary(uniqueKeysWithValues: local.map { ($0.identity, $0) })
            for archived in incoming {
                let row = normalized(archived, supplementalFields: allowed)
                guard seen.insert(row.identity).inserted else { throw Failure.duplicateIdentity }
                guard let current = byID[row.identity] else {
                    additions.append(row)
                    continue
                }
                guard current != row else { continue }
                guard let id = UUID(uuidString: row.identity) else { throw Failure.destinationConflict }
                // UUIDs belong to their model table; a workout and a set may legally share a UUID.
                let workout = table.name == "ExerciseRecord" ? parents.exercises[id] : nil
                let set = table.name == "WorkoutSet" ? localSets[id] : nil
                if try enrich(current, from: row, fields: allowed, workout: workout, set: set) { enriched += 1 }
            }
            try table.stage(additions, context, &parents)
            inserted += additions.count
        }
        // Native HealthKit callbacks can update PR/reward defaults while rows are being staged.
        // Re-read under their lock just before commit. A new conflict aborts all provisional rows.
        try PersonalRecordStore.withMutationLock {
            let currentPreferences = try Preferences(defaults)
            let preferences: Preferences
            switch mode {
            case .emptyOrMatching:
                guard try archive.preferences.contains(currentPreferences) else { throw Failure.destinationConflict }
                preferences = archive.preferences
            case .mergeAfterOwnershipVerification:
                preferences = try archive.preferences.merged(with: currentPreferences)
            }
            if context.hasChanges { try context.save() }
            // Retry repairs an interruption between database commit and defaults installation.
            preferences.install(into: defaults)
        }
        return RestoreResult(
            archiveRowCount: archive.tables.values.reduce(0) { $0 + $1.count },
            workoutCount: archive.tables["ExerciseRecord", default: []].count,
            setCount: archive.tables["WorkoutSet", default: []].count,
            insertedRowCount: inserted, enrichedRowCount: enriched
        )
    }
}
