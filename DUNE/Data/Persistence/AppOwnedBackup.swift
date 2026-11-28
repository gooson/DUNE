import Foundation
import CoreFoundation
import SwiftData

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

        init<V: Codable>(_ name: String, _ path: ReferenceWritableKeyPath<M, V>) {
            self.name = name
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

        // The persisted layout comes from PersonalRecordStore.RewardState.
        private struct RewardValue: Decodable {
            let milestoneTierByActivity: [String: Int]
            let unlockedBadges: [String]
            let totalPoints: Int
            let level: Int
            let history: [WorkoutRewardEvent]
            let processedWorkoutSignatures: [String: String]
        }

        func validate() throws {
            try settings?.validate()
            if let rewards { _ = try JSONDecoder().decode(RewardValue.self, from: rewards) }
            for (key, data) in records {
                guard WorkoutActivityType(rawValue: key) != nil else { throw Failure.invalidArchive }
                _ = try JSONDecoder().decode([PersonalRecordType: PersonalRecord].self, from: data)
            }
        }

        func contains(_ existing: Self) throws -> Bool {
            let selected = settings ?? Settings()
            return try selected.merging(existing.settings ?? Settings()) == selected
                && (existing.rewards == nil || existing.rewards == rewards)
                && (existing.titles == nil || existing.titles == titles)
                && existing.records.allSatisfy { records[$0.key] == $0.value }
        }

        func merged(with local: Self) throws -> Self {
            func same<T: Equatable>(_ a: T, _ b: T) throws -> T {
                guard a == b else { throw Failure.destinationConflict }
                return a
            }
            var result = self
            let selected = try (settings ?? Settings()).merging(local.settings ?? Settings())
            result.settings = selected == Settings() ? nil : selected
            if let existing = local.rewards {
                result.rewards = try rewards.map { try same($0, existing) } ?? existing
            }
            result.records = try local.records.merging(records, uniquingKeysWith: same)
            if local.titles != nil || titles != nil {
                result.titles = try (local.titles ?? [:]).merging(titles ?? [:], uniquingKeysWith: same)
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
        let archive = try Archive(version: 1, tables: snapshot(context), preferences: Preferences(defaults))
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

        let currentPreferences = try Preferences(defaults)
        let preferences: Preferences
        switch mode {
        case .emptyOrMatching:
            guard try archive.preferences.contains(currentPreferences) else { throw Failure.destinationConflict }
            preferences = archive.preferences
        case .mergeAfterOwnershipVerification:
            preferences = try archive.preferences.merged(with: currentPreferences)
        }
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
        if context.hasChanges { try context.save() }
        // A crash after the database commit is repairable by retrying the same archive.
        preferences.install(into: defaults)
        return RestoreResult(
            archiveRowCount: archive.tables.values.reduce(0) { $0 + $1.count },
            workoutCount: archive.tables["ExerciseRecord", default: []].count,
            setCount: archive.tables["WorkoutSet", default: []].count,
            insertedRowCount: inserted, enrichedRowCount: enriched
        )
    }
}
