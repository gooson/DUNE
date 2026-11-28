import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("App-owned recovery archive")
@MainActor
struct AppOwnedBackupTests {
    @MainActor
    private struct Device {
        let container: ModelContainer
        let defaults: UserDefaults
        let suite: String
        var context: ModelContext { container.mainContext }

        init() throws {
            let schema = AppSchema.currentSchema
            container = try ModelContainer(for: schema, configurations: ModelConfiguration(
                schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
            ))
            let suiteName = "AppOwnedBackupTests." + UUID().uuidString
            suite = suiteName
            defaults = try #require(UserDefaults(suiteName: suiteName))
        }
        func clean() { defaults.removePersistentDomain(forName: suite) }
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    private func binary(_ value: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }

    @Test func driveFileContainsOnlyVisualChoicesAndRestoresIdempotently() throws {
        let from = try Device(), to = try Device()
        defer { from.clean(); to.clean() }
        from.defaults.set(AppTheme.oceanCool.rawValue, forKey: AppTheme.storageKey)
        from.defaults.set(AppIconStyle.flow.rawValue, forKey: AppIconStyle.storageKey)
        from.defaults.set(WeightUnit.lb.rawValue, forKey: WeightUnit.storageKey)
        let visual = try AppOwnedBackup.encodeDriveSettings(defaults: from.defaults)
        let prefix = Bundle.main.bundleIdentifier ?? "com.dailve"
        from.defaults.set(["workout": "private name"], forKey: "workout.type.corrections.v1")
        from.defaults.set(Data("private reward".utf8), forKey: prefix + ".workoutRewards.state")
        from.defaults.set(Data("private PR".utf8), forKey: prefix + ".personalRecords.walking")
        from.defaults.set(Data([0, 1, 2, 3]), forKey: "privatePhoto")
        let training = WorkoutSettingsStore(defaults: from.defaults)
        training.restSeconds = 45
        training.setCount = 3
        training.bodyWeightKg = 66
        #expect(try AppOwnedBackup.encodeDriveSettings(defaults: from.defaults) == visual)
        for _ in 0..<2 {
            #expect(try AppOwnedBackup.restoreDriveSettingsIfPresent(visual, defaults: to.defaults))
        }
        #expect(to.defaults.string(forKey: AppTheme.storageKey) == AppTheme.oceanCool.rawValue)
        #expect(to.defaults.string(forKey: AppIconStyle.storageKey) == AppIconStyle.flow.rawValue)
        #expect(to.defaults.string(forKey: WeightUnit.storageKey) == WeightUnit.lb.rawValue)
        let savedKeys = Set(to.defaults.persistentDomain(forName: to.suite)?.keys.map { $0 } ?? [])
        #expect(savedKeys == Set([AppTheme.storageKey, AppIconStyle.storageKey, WeightUnit.storageKey]))
    }

    @Test func driveFileRejectsExtraFieldsInvalidCodesAndConflictsWithoutPartialWrites() throws {
        let from = try Device(), to = try Device()
        defer { from.clean(); to.clean() }
        #expect(try !AppOwnedBackup.restoreDriveSettingsIfPresent(Data(), defaults: to.defaults))
        #expect(try !AppOwnedBackup.restoreDriveSettingsIfPresent(Data("unrelated file".utf8), defaults: to.defaults))
        let empty = try AppOwnedBackup.encodeDriveSettings(defaults: from.defaults)
        #expect(try AppOwnedBackup.restoreDriveSettingsIfPresent(empty, defaults: to.defaults))
        #expect((to.defaults.persistentDomain(forName: to.suite) ?? [:]).isEmpty)
        from.defaults.set(AppTheme.sakuraCalm.rawValue, forKey: AppTheme.storageKey)
        from.defaults.set(WeightUnit.kg.rawValue, forKey: WeightUnit.storageKey)
        let valid = try AppOwnedBackup.encodeDriveSettings(defaults: from.defaults)
        var invalidCode = valid
        invalidCode[invalidCode.endIndex - 1] = 255
        for invalid in [invalidCode, Data(valid.dropLast()), valid + Data("extra personal field".utf8)] {
            #expect(throws: AppOwnedBackup.Failure.invalidArchive) {
                try AppOwnedBackup.restoreDriveSettingsIfPresent(invalid, defaults: to.defaults)
            }
        }
        var future = valid
        future[future.endIndex - 4] = 99
        #expect(throws: AppOwnedBackup.Failure.unsupportedVersion) {
            try AppOwnedBackup.restoreDriveSettingsIfPresent(future, defaults: to.defaults)
        }
        to.defaults.set(WeightUnit.lb.rawValue, forKey: WeightUnit.storageKey)
        #expect(throws: AppOwnedBackup.Failure.destinationConflict) {
            try AppOwnedBackup.restoreDriveSettingsIfPresent(valid, defaults: to.defaults)
        }
        #expect(to.defaults.object(forKey: AppTheme.storageKey) == nil)
        #expect(to.defaults.string(forKey: WeightUnit.storageKey) == WeightUnit.lb.rawValue)
        from.defaults.set("private user text", forKey: AppTheme.storageKey)
        #expect(throws: AppOwnedBackup.Failure.invalidArchive) {
            try AppOwnedBackup.encodeDriveSettings(defaults: from.defaults)
        }
    }

    @Test func restoresAllOwnedTablesLinksPhotosPreferencesAndExactRepeat() throws {
        let from = try Device(), to = try Device()
        defer { from.clean(); to.clean() }
        let workout = ExerciseRecord(exerciseType: "Private exercise", duration: 43, memo: "private note")
        let linked = ExerciseRecord(exerciseType: "Second exercise", duration: 12)
        let sharedHealthID = UUID().uuidString
        workout.healthKitWorkoutID = sharedHealthID
        linked.healthKitWorkoutID = sharedHealthID
        let set = WorkoutSet(setNumber: 2, weight: 17.5, reps: 7, plannedReps: 9)
        set.exerciseRecord = workout
        let location = WorkoutLocationRecord(localRecordID: workout.id, healthKitWorkoutID: sharedHealthID,
                                            payload: WorkoutLocationPayload(isIndoor: true))
        let habit = HabitDefinition(name: "Private habit", iconCategory: .health, habitType: .check,
                                   goalValue: 1, goalUnit: nil, frequency: .daily)
        let log = HabitLog(date: .now, value: 1, memo: "done")
        log.habitDefinition = habit
        let portrait = PostureAssessmentRecord(frontImageData: Data([1, 2, 3]), sideImageData: Data([4, 5]))
        portrait.sideMetricsJSON = "[{\"fixture\":1}]"
        let injury = InjuryRecord(bodyPart: .knee, bodySide: nil, severity: .moderate, startDate: .now, memo: "previous")
        let category = UserCategory(name: "Personal category")
        let custom = CustomExercise(name: "My exercise", category: .strength, inputType: .setsRepsWeight,
                                    primaryMuscles: [], equipment: .bodyweight, customCategoryName: category.name)
        let entry = TemplateEntry(exerciseDefinitionID: custom.id.uuidString, exerciseName: custom.name,
                                  defaultWeightKg: 12.5, restDuration: 45)
        let template = WorkoutTemplate(name: "My routine", exerciseEntries: [entry])
        from.context.insert(workout)
        from.context.insert(linked)
        from.context.insert(set)
        from.context.insert(location)
        from.context.insert(habit)
        from.context.insert(log)
        from.context.insert(portrait)
        from.context.insert(injury)
        from.context.insert(category)
        from.context.insert(custom)
        from.context.insert(template)
        from.context.insert(ExerciseDefaultRecord(exerciseDefinitionID: custom.id.uuidString, defaultWeight: 7.5))
        from.context.insert(BodyCompositionRecord(weight: 65.5, muscleMass: 29, memo: "manual"))
        from.context.insert(HourlyScoreSnapshot(date: .now, conditionScore: 74))
        from.context.insert(HealthSnapshotMirrorRecord(payloadJSON: "{\"privateMirror\":true}"))
        try from.context.save()
        let prefix = Bundle.main.bundleIdentifier ?? "com.dailve"
        let rewards = Data(#"{"milestoneTierByActivity":{},"unlockedBadges":["badge"],"totalPoints":15,"level":1,"history":[],"processedWorkoutSignatures":{}}"#.utf8)
        from.defaults.set(rewards, forKey: prefix + ".workoutRewards.state")
        let pr = PersonalRecord(type: .longestDuration, value: 43, date: workout.date, workoutID: sharedHealthID)
        from.defaults.set(try JSONEncoder().encode([PersonalRecordType.longestDuration: pr]),
                          forKey: prefix + ".personalRecords.walking")
        from.defaults.set(["test-workout": "My label"], forKey: "workout.type.corrections.v1")
        from.defaults.set(AppTheme.forestGreen.rawValue, forKey: AppTheme.storageKey)
        from.defaults.set(AppIconStyle.flow.rawValue, forKey: AppIconStyle.storageKey)
        from.defaults.set(WeightUnit.lb.rawValue, forKey: WeightUnit.storageKey)
        let training = WorkoutSettingsStore(defaults: from.defaults)
        training.restSeconds = 75
        training.setCount = 4
        training.bodyWeightKg = 62.5
        from.defaults.set("excluded", forKey: "nearbyWorkoutVerifiedAccount")
        to.defaults.set("device setting", forKey: "uiOnly")

        let bytes = try AppOwnedBackup.encode(from: from.context, defaults: from.defaults)
        // A new SwiftData entity, attribute or relationship must be consciously added to the archive.
        let source = try object(bytes)
        let tables = try #require(source["tables"] as? [String: [[String: Any]]])
        let owned = AppSchema.currentSchema.entities.filter { $0.name != "HealthSnapshotMirrorRecord" }
        #expect(Set(owned.map(\.name)) == Set(tables.keys))
        let relationships: [String: Set<String>] = [
            "ExerciseRecord": ["sets"], "WorkoutSet": ["exerciseRecord"],
            "HabitDefinition": ["logs"], "HabitLog": ["habitDefinition"],
        ]
        for entity in owned {
            let row = try #require(tables[entity.name]?.first)
            let saved = try #require(row["fields"] as? [String: Data])
            let mapped = Set(saved.keys).union(relationships[entity.name] ?? [])
            #expect(mapped == Set(entity.properties.map(\.name)))
        }
        let key = EncryptedRecoveryArchive.makeRecoveryKey()
        let encrypted = try EncryptedRecoveryArchive.seal(bytes, recoveryKey: key)
        #expect(encrypted != bytes)
        let decrypted = try EncryptedRecoveryArchive.open(encrypted, recoveryKey: key)
        #expect(decrypted == bytes)
        try AppOwnedBackup.restore(decrypted, into: to.context, defaults: to.defaults)
        try AppOwnedBackup.restore(decrypted, into: to.context, defaults: to.defaults)

        let check = ModelContext(to.container)
        let restored = try #require(check.fetch(FetchDescriptor<WorkoutSet>()).first)
        #expect(restored.id == set.id && restored.exerciseRecord?.id == workout.id && restored.weight == 17.5)
        #expect(try check.fetchCount(FetchDescriptor<ExerciseRecord>()) == 2)
        #expect(try check.fetch(FetchDescriptor<HabitLog>()).first?.habitDefinition?.id == habit.id)
        #expect(try check.fetch(FetchDescriptor<WorkoutLocationRecord>()).first?.payloadData == location.payloadData)
        let restoredPortrait = try #require(check.fetch(FetchDescriptor<PostureAssessmentRecord>()).first)
        #expect(restoredPortrait.frontImageData == portrait.frontImageData && restoredPortrait.sideImageData == portrait.sideImageData)
        #expect(try check.fetch(FetchDescriptor<WorkoutTemplate>()).first?.exerciseEntries.first?.id == entry.id)
        #expect(try check.fetchCount(FetchDescriptor<HealthSnapshotMirrorRecord>()) == 0)
        #expect(PersonalRecordStore(defaults: to.defaults).rewardSummary().totalPoints == 15)
        #expect(PersonalRecordStore(defaults: to.defaults).records(for: .walking)[.longestDuration]?.value == 43)
        #expect(WorkoutTypeCorrectionStore(userDefaults: to.defaults).correctedTitle(for: "test-workout") == "My label")
        #expect(to.defaults.object(forKey: "nearbyWorkoutVerifiedAccount") == nil)
        #expect(to.defaults.string(forKey: "uiOnly") == "device setting")
        #expect(to.defaults.string(forKey: AppTheme.storageKey) == AppTheme.forestGreen.rawValue)
        #expect(to.defaults.string(forKey: AppIconStyle.storageKey) == AppIconStyle.flow.rawValue)
        #expect(to.defaults.string(forKey: WeightUnit.storageKey) == WeightUnit.lb.rawValue)
        let restoredSettings = WorkoutSettingsStore(defaults: to.defaults)
        #expect(restoredSettings.restSeconds == 75 && restoredSettings.setCount == 4 && restoredSettings.bodyWeightKg == 62.5)
        let recovered = try AppOwnedBackup.encode(from: check, defaults: to.defaults)
        #expect(try NSDictionary(dictionary: object(bytes)).isEqual(to: object(recovered)))
    }

    @Test func rejectsUnsupportedUnitsAndBooleanMasqueradingAsAWorkoutCount() throws {
        let device = try Device()
        defer { device.clean() }
        device.defaults.set("unexpected", forKey: WeightUnit.storageKey)
        #expect(throws: AppOwnedBackup.Failure.invalidArchive) {
            try AppOwnedBackup.encode(from: device.context, defaults: device.defaults)
        }
        device.defaults.removeObject(forKey: WeightUnit.storageKey)
        let prefix = Bundle.main.bundleIdentifier ?? "com.dailve"
        device.defaults.set(true, forKey: prefix + ".settings.setCount")
        #expect(throws: AppOwnedBackup.Failure.invalidArchive) {
            try AppOwnedBackup.encode(from: device.context, defaults: device.defaults)
        }
    }

    @Test func lateOrphanCorruptionAndUnknownVersionsRollBackEverything() throws {
        let from = try Device(), to = try Device()
        defer { from.clean(); to.clean() }
        let workout = ExerciseRecord(exerciseType: "preserve")
        let set = WorkoutSet(setNumber: 1)
        set.exerciseRecord = workout
        from.context.insert(workout)
        from.context.insert(set)
        try from.context.save()
        from.defaults.set(["id": "source"], forKey: "workout.type.corrections.v1")
        let bytes = try AppOwnedBackup.encode(from: from.context, defaults: from.defaults)
        var archive = try object(bytes)
        var tables = try #require(archive["tables"] as? [String: [[String: Any]]])
        var row = try #require(tables["WorkoutSet"]?.first)
        row["parent"] = UUID().uuidString
        tables["WorkoutSet"] = [row]
        archive["tables"] = tables
        #expect(throws: AppOwnedBackup.Failure.missingParent) {
            try AppOwnedBackup.restore(binary(archive), into: to.context, defaults: to.defaults)
        }
        #expect(try ModelContext(to.container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 0)
        #expect(to.defaults.object(forKey: "workout.type.corrections.v1") == nil)
        archive["version"] = 17
        #expect(throws: AppOwnedBackup.Failure.unsupportedVersion) {
            try AppOwnedBackup.restore(binary(archive), into: to.context, defaults: to.defaults)
        }
        #expect(throws: (any Error).self) {
            try AppOwnedBackup.restore(Data(bytes.prefix(10)), into: to.context, defaults: to.defaults)
        }
    }

    @Test func verifiedMergePreservesDeviceGeneratedRowsAndLinksNewChildrenToExistingParents() throws {
        let from = try Device(), to = try Device()
        defer { from.clean(); to.clean() }
        let workout = ExerciseRecord(exerciseType: "archived")
        from.context.insert(workout)
        try from.context.save()
        let initial = try AppOwnedBackup.encode(from: from.context, defaults: from.defaults)
        try AppOwnedBackup.restore(initial, into: to.context, defaults: to.defaults)
        let score = HourlyScoreSnapshot(date: Date(timeIntervalSince1970: 3600), conditionScore: 82)
        to.context.insert(score)
        try to.context.save()
        let key = "workout.type.corrections.v1"
        from.defaults.set(["shared": "same", "from-backup": "my title"], forKey: key)
        to.defaults.set(["shared": "same", "new-device": "local title"], forKey: key)
        let set = WorkoutSet(setNumber: 1, reps: 3)
        set.exerciseRecord = workout
        from.context.insert(set)
        try from.context.save()
        let archive = try AppOwnedBackup.encode(from: from.context, defaults: from.defaults)
        #expect(throws: AppOwnedBackup.Failure.destinationConflict) {
            try AppOwnedBackup.restore(archive, into: to.context, defaults: to.defaults)
        }
        for _ in 0..<2 {
            try AppOwnedBackup.restore(archive, into: to.context, defaults: to.defaults,
                                       mode: .mergeAfterOwnershipVerification)
        }
        let read = ModelContext(to.container)
        let setRows = try read.fetch(FetchDescriptor<WorkoutSet>())
        #expect(setRows.count == 1 && setRows.first?.exerciseRecord?.id == workout.id)
        #expect(try read.fetchCount(FetchDescriptor<ExerciseRecord>()) == 1)
        #expect(try read.fetch(FetchDescriptor<HourlyScoreSnapshot>()).first?.conditionScore == 82)
        #expect(to.defaults.dictionary(forKey: key) as? [String: String] ==
                ["shared": "same", "from-backup": "my title", "new-device": "local title"])

        // Same child UUID with a new parent is a conflict, even though both parent UUIDs exist.
        let alternate = ExerciseRecord(exerciseType: "alternate")
        from.context.insert(alternate)
        set.exerciseRecord = alternate
        try from.context.save()
        let conflicting = try AppOwnedBackup.encode(from: from.context, defaults: from.defaults)
        #expect(throws: AppOwnedBackup.Failure.destinationConflict) {
            try AppOwnedBackup.restore(conflicting, into: to.context, defaults: to.defaults,
                                       mode: .mergeAfterOwnershipVerification)
        }
        #expect(try ModelContext(to.container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 1)
        #expect(try ModelContext(to.container).fetch(FetchDescriptor<WorkoutSet>()).first?.exerciseRecord?.id == workout.id)
    }

    @Test func verifiedWorkoutMergeSupplementsOnlyAbsentLaterFieldsAndRollsBackCompetingValues() throws {
        let from = try Device(), to = try Device()
        defer { from.clean(); to.clean() }
        let workout = ExerciseRecord(exerciseType: "fixture", duration: 99)
        let set = WorkoutSet(setNumber: 1, reps: 5)
        set.exerciseRecord = workout
        from.context.insert(workout)
        from.context.insert(set)
        try from.context.save()
        let baseline = try AppOwnedBackup.encode(from: from.context, defaults: from.defaults)
        let first = try AppOwnedBackup.restore(baseline, into: to.context, defaults: to.defaults)
        #expect(first.archiveRowCount == 2 && first.workoutCount == 1 && first.setCount == 1)
        #expect(first.insertedRowCount == 2 && first.enrichedRowCount == 0)

        // One device has the old workout count and set effort source, the other has the other two fields.
        workout.plannedSetCount = 6
        set.rpeSourceRaw = "watch"
        try from.context.save()
        let localWorkout = try #require(to.context.fetch(FetchDescriptor<ExerciseRecord>()).first)
        let localSet = try #require(to.context.fetch(FetchDescriptor<WorkoutSet>()).first)
        localWorkout.effortSourceRaw = "user"
        localSet.plannedReps = 8
        try to.context.save()
        var archive = try object(AppOwnedBackup.encode(from: from.context, defaults: from.defaults))
        var tables = try #require(archive["tables"] as? [String: [[String: Any]]])
        // Some earlier exports may omit an optional key entirely instead of encoding null.
        var archivedWorkout = try #require(tables["ExerciseRecord"]?.first)
        var fields = try #require(archivedWorkout["fields"] as? [String: Data])
        fields.removeValue(forKey: "effortSourceRaw")
        archivedWorkout["fields"] = fields
        tables["ExerciseRecord"] = [archivedWorkout]
        archive["tables"] = tables
        let incoming = try binary(archive)
        #expect(throws: AppOwnedBackup.Failure.destinationConflict) {
            try AppOwnedBackup.restore(incoming, into: to.context, defaults: to.defaults)
        }
        let result = try AppOwnedBackup.restore(incoming, into: to.context, defaults: to.defaults,
                                                mode: .mergeAfterOwnershipVerification)
        #expect(result.insertedRowCount == 0 && result.enrichedRowCount == 2)
        let repeated = try AppOwnedBackup.restore(incoming, into: to.context, defaults: to.defaults,
                                                  mode: .mergeAfterOwnershipVerification)
        #expect(repeated.insertedRowCount == 0 && repeated.enrichedRowCount == 0)
        let read = ModelContext(to.container)
        let combined = try #require(read.fetch(FetchDescriptor<ExerciseRecord>()).first)
        let child = try #require(read.fetch(FetchDescriptor<WorkoutSet>()).first)
        #expect(combined.plannedSetCount == 6 && combined.effortSourceRaw == "user")
        #expect(child.plannedReps == 8 && child.rpeSourceRaw == "watch" && child.exerciseRecord?.id == workout.id)

        // The workout's provisional enrichment precedes a later set conflict. Neither may be committed.
        combined.plannedSetCount = nil
        child.rpeSourceRaw = "local"
        try read.save()
        #expect(throws: AppOwnedBackup.Failure.destinationConflict) {
            try AppOwnedBackup.restore(incoming, into: read, defaults: to.defaults, mode: .mergeAfterOwnershipVerification)
        }
        let after = ModelContext(to.container)
        #expect(try after.fetch(FetchDescriptor<ExerciseRecord>()).first?.plannedSetCount == nil)
        #expect(try after.fetch(FetchDescriptor<WorkoutSet>()).first?.rpeSourceRaw == "local")
    }

    @Test func encryptedFullHistoryRecovers410WorkoutsAnd1979SetsOverALegacyDestination() throws {
        func stableID(_ family: UInt8, _ index: Int) -> UUID {
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, family, 0, 0, 0, 0,
                        UInt8(index >> 8), UInt8(truncatingIfNeeded: index)))
        }
        func numberOfSets(_ index: Int) -> Int {
            if index < 349 { return 5 }
            return index < 400 ? 4 : 3
        }
        let markedWorkouts = [19, 409]
        func seed(_ device: Device, legacy: Bool) throws {
            let context = device.context
            for index in 0..<(legacy ? 400 : 410) {
                let date = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 3600)
                let count = numberOfSets(index)
                let exercise = ExerciseRecord(date: date, exerciseType: "Fixture exercise", duration: 900)
                exercise.id = stableID(1, index)
                exercise.createdAt = date
                exercise.healthKitWorkoutID = stableID(2, index).uuidString
                exercise.plannedSetCount = legacy ? nil : count
                exercise.effortSourceRaw = legacy ? nil : "user"
                context.insert(exercise)
                for sequence in 0..<count {
                    let child = WorkoutSet(setNumber: sequence + 1, weight: 20, reps: 8, isCompleted: true,
                                           plannedReps: legacy ? nil : 10, rpeSourceRaw: legacy ? nil : "estimated")
                    child.id = stableID(3, index * 8 + sequence)
                    child.exerciseRecord = exercise
                    context.insert(child)
                }
                if !legacy && markedWorkouts.contains(index) {
                    let place = try #require(WorkoutPlace(latitude: 0, longitude: Double(index) / 10,
                                                          name: "Fixture gym \(index)", source: .manual))
                    let location = WorkoutLocationRecord(localRecordID: exercise.id,
                                                         healthKitWorkoutID: exercise.healthKitWorkoutID,
                                                         payload: WorkoutLocationPayload(isIndoor: true, place: place))
                    location.id = stableID(4, index)
                    location.updatedAt = date
                    context.insert(location)
                    WorkoutTypeCorrectionStore(userDefaults: device.defaults)
                        .setCorrectedTitle("Fixture title \(index)", for: stableID(2, index).uuidString)
                }
            }
            try context.save()
        }
        let key = EncryptedRecoveryArchive.makeRecoveryKey()
        let encrypted = try autoreleasepool {
            let source = try Device()
            defer { source.clean() }
            try seed(source, legacy: false)
            let bytes = try AppOwnedBackup.encode(from: source.context, defaults: source.defaults)
            return try EncryptedRecoveryArchive.seal(bytes, recoveryKey: key)
        }
        let destination = try Device()
        defer { destination.clean() }
        try seed(destination, legacy: true)
        #expect(try destination.context.fetchCount(FetchDescriptor<ExerciseRecord>()) == 400)
        #expect(try destination.context.fetchCount(FetchDescriptor<WorkoutSet>()) == 1_949)
        let decrypted = try EncryptedRecoveryArchive.open(encrypted, recoveryKey: key)
        let imported = try AppOwnedBackup.restore(decrypted, into: destination.context, defaults: destination.defaults,
                                                  mode: .mergeAfterOwnershipVerification)
        #expect(imported.workoutCount == 410 && imported.setCount == 1_979)
        #expect(imported.insertedRowCount == 42 && imported.enrichedRowCount == 2_349)
        let repeated = try AppOwnedBackup.restore(decrypted, into: destination.context, defaults: destination.defaults,
                                                  mode: .mergeAfterOwnershipVerification)
        #expect(repeated.insertedRowCount == 0 && repeated.enrichedRowCount == 0)

        let read = ModelContext(destination.container)
        let workouts = try read.fetch(FetchDescriptor<ExerciseRecord>())
        let sets = try read.fetch(FetchDescriptor<WorkoutSet>())
        let locations = try read.fetch(FetchDescriptor<WorkoutLocationRecord>())
        #expect(workouts.count == 410 && sets.count == 1_979 && locations.count == 2)
        let indices = Dictionary(uniqueKeysWithValues: (0..<410).map { (stableID(1, $0), $0) })
        let groups = Dictionary(grouping: sets, by: { $0.exerciseRecord?.id })
        #expect(Set(workouts.map(\.id)) == Set(indices.keys))
        for workout in workouts {
            let index = try #require(indices[workout.id])
            let count = numberOfSets(index)
            #expect(workout.plannedSetCount == count && workout.effortSourceRaw == "user")
            let children = groups[workout.id] ?? []
            let expectedIDs = Set((0..<count).map { stableID(3, index * 8 + $0) })
            #expect(Set(children.map(\.id)) == expectedIDs)
        }
        #expect(sets.allSatisfy { $0.plannedReps == 10 && $0.rpeSourceRaw == "estimated" && $0.reps == 8 })
        let corrections = WorkoutTypeCorrectionStore(userDefaults: destination.defaults)
        for index in markedWorkouts {
            let id = stableID(2, index).uuidString
            let location = try #require(locations.first { $0.localRecordID == stableID(1, index) })
            #expect(location.healthKitWorkoutID == id && location.payload?.isIndoor == true)
            #expect(location.payload?.place?.name == "Fixture gym \(index)")
            #expect(location.payload?.place?.longitude == Double(index) / 10)
            #expect(corrections.correctedTitle(for: id) == "Fixture title \(index)")
        }
    }

    @Test func preferencesOnlyRestoreReportsZeroAppRowsAndWorkouts() throws {
        let from = try Device(), to = try Device()
        defer { from.clean(); to.clean() }
        from.defaults.set(WeightUnit.lb.rawValue, forKey: WeightUnit.storageKey)
        let bytes = try AppOwnedBackup.encode(from: from.context, defaults: from.defaults)
        let result = try AppOwnedBackup.restore(bytes, into: to.context, defaults: to.defaults)
        #expect(result.archiveRowCount == 0 && result.workoutCount == 0 && result.setCount == 0)
        #expect(result.insertedRowCount == 0 && result.enrichedRowCount == 0)
        #expect(to.defaults.string(forKey: WeightUnit.storageKey) == WeightUnit.lb.rawValue)
    }

    @Test func malformedExerciseDefaultIDIsRejectedBeforeModelInitialization() throws {
        let from = try Device(), to = try Device()
        defer { from.clean(); to.clean() }
        from.context.insert(ExerciseDefaultRecord(exerciseDefinitionID: "valid-id"))
        try from.context.save()
        var archive = try object(AppOwnedBackup.encode(from: from.context, defaults: from.defaults))
        var tables = try #require(archive["tables"] as? [String: [[String: Any]]])
        var row = try #require(tables["ExerciseDefaultRecord"]?.first)
        var fields = try #require(row["fields"] as? [String: Data])
        fields["exerciseDefinitionID"] = try JSONEncoder().encode("")
        row["fields"] = fields
        tables["ExerciseDefaultRecord"] = [row]
        archive["tables"] = tables
        #expect(throws: AppOwnedBackup.Failure.invalidArchive) {
            try AppOwnedBackup.restore(binary(archive), into: to.context, defaults: to.defaults)
        }
        #expect(try ModelContext(to.container).fetchCount(FetchDescriptor<ExerciseDefaultRecord>()) == 0)
    }

    @Test func rejectsDuplicateIdentitiesAndDamagedAttachmentBeforeCommitting() throws {
        let from = try Device(), to = try Device()
        defer { from.clean(); to.clean() }
        from.context.insert(ExerciseRecord(exerciseType: "fixture"))
        from.context.insert(PostureAssessmentRecord(frontImageData: Data([10])))
        try from.context.save()
        let source = try AppOwnedBackup.encode(from: from.context, defaults: from.defaults)
        var archive = try object(source)
        var tables = try #require(archive["tables"] as? [String: [[String: Any]]])
        let workout = try #require(tables["ExerciseRecord"]?.first)
        tables["ExerciseRecord"] = [workout, workout]
        archive["tables"] = tables
        #expect(throws: AppOwnedBackup.Failure.duplicateIdentity) {
            try AppOwnedBackup.restore(binary(archive), into: to.context, defaults: to.defaults)
        }
        tables["ExerciseRecord"] = [workout]
        var portrait = try #require(tables["PostureAssessmentRecord"]?.first)
        var fields = try #require(portrait["fields"] as? [String: Data])
        fields["frontImageData"] = Data([7])
        portrait["fields"] = fields
        tables["PostureAssessmentRecord"] = [portrait]
        archive["tables"] = tables
        #expect(throws: AppOwnedBackup.Failure.invalidArchive) {
            try AppOwnedBackup.restore(binary(archive), into: to.context, defaults: to.defaults)
        }
        #expect(try ModelContext(to.container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 0)
    }

    @Test func refusesDifferentDestinationAndResumesCommittedRowsWithMissingDefaults() throws {
        let from = try Device(), to = try Device()
        defer { from.clean(); to.clean() }
        from.context.insert(ExerciseRecord(exerciseType: "source"))
        try from.context.save()
        let key = "workout.type.corrections.v1"
        from.defaults.set(["id": "source title"], forKey: key)
        let bytes = try AppOwnedBackup.encode(from: from.context, defaults: from.defaults)
        to.defaults.set(["id": "existing title"], forKey: key)
        #expect(throws: AppOwnedBackup.Failure.destinationConflict) {
            try AppOwnedBackup.restore(bytes, into: to.context, defaults: to.defaults)
        }
        #expect(try ModelContext(to.container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 0)
        to.defaults.removeObject(forKey: key)
        try AppOwnedBackup.restore(bytes, into: to.context, defaults: to.defaults)
        to.defaults.removeObject(forKey: key)
        try AppOwnedBackup.restore(bytes, into: to.context, defaults: to.defaults)
        #expect(to.defaults.dictionary(forKey: key) as? [String: String] == ["id": "source title"])
        let local = try #require(to.context.fetch(FetchDescriptor<ExerciseRecord>()).first)
        local.memo = "unsaved"
        #expect(throws: AppOwnedBackup.Failure.unsavedChanges) {
            try AppOwnedBackup.restore(bytes, into: to.context, defaults: to.defaults)
        }
        try to.context.save()
        #expect(throws: AppOwnedBackup.Failure.destinationConflict) {
            try AppOwnedBackup.restore(bytes, into: to.context, defaults: to.defaults)
        }
        #expect(local.memo == "unsaved")
    }
}
