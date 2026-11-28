import CryptoKit
import Foundation
import SQLite3
import SwiftData
import Testing
@testable import DUNE

@Suite("AppSchema")
struct AppSchemaTests {
    @Test("Current schema contains all expected model entities")
    func currentSchemaContainsAllModels() {
        let currentModelNames = Set(AppSchema.currentSchema.entities.map(\.name))

        #expect(currentModelNames.contains("ExerciseRecord"))
        #expect(currentModelNames.contains("BodyCompositionRecord"))
        #expect(currentModelNames.contains("WorkoutSet"))
        #expect(currentModelNames.contains("CustomExercise"))
        #expect(currentModelNames.contains("WorkoutTemplate"))
        #expect(currentModelNames.contains("InjuryRecord"))
        #expect(currentModelNames.contains("HabitDefinition"))
        #expect(currentModelNames.contains("HabitLog"))
        #expect(currentModelNames.contains("UserCategory"))
        #expect(currentModelNames.contains("ExerciseDefaultRecord"))
        #expect(currentModelNames.contains("HealthSnapshotMirrorRecord"))
        #expect(currentModelNames.contains("HourlyScoreSnapshot"))
        #expect(currentModelNames.contains("PostureAssessmentRecord"))
        #expect(currentModelNames.contains("WorkoutLocationRecord"))
        #expect(currentModelNames.count == 14)
    }

    @Test("Schema builds an in-memory model container")
    func schemaBuildsContainer() throws {
        _ = try ModelContainer(
            for: AppSchema.currentSchema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    @Test("Historical entity names remain in the current schema")
    func historicalEntityNames() {
        let oldNames = Set(Schema(AppSchemaV17.models).entities.map(\.name))
        let newNames = Set(AppSchema.currentSchema.entities.map(\.name))
        #expect(oldNames.isSubset(of: newNames))
        #expect(oldNames.contains("ExerciseRecord"))
        #expect(oldNames.contains("WorkoutSet"))
    }

    @Test("V17 workout migrates and new metadata survives a second reopen")
    func v17WorkoutMigratesAndReopens() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }
        let oldSchema = Schema(AppSchemaV17.models)

        do {
            let configuration = ModelConfiguration(schema: oldSchema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: oldSchema, configurations: configuration)
            let context = ModelContext(container)
            let record = AppSchemaV17.ExerciseRecord(exerciseType: "Squat", duration: 600, rpe: 8)
            let set = AppSchemaV17.WorkoutSet(setNumber: 1, weight: 80, reps: 5, isCompleted: true, rpe: 8.5)
            set.exerciseRecord = record
            record.sets = [set]
            context.insert(record)
            try context.save()
        }

        do {
            let configuration = ModelConfiguration(schema: AppSchema.currentSchema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: AppSchema.currentSchema, configurations: configuration)
            let context = ModelContext(container)
            let records = try context.fetch(FetchDescriptor<ExerciseRecord>())
            #expect(records.count == 1)
            let record = try #require(records.first)
            #expect(record.exerciseType == "Squat")
            #expect(record.duration == 600)
            #expect(record.rpe == 8)
            #expect(record.plannedSetCount == nil)
            #expect(record.effortSourceRaw == nil)
            let set = try #require(record.sets?.first)
            #expect(set.reps == 5)
            #expect(set.weight == 80)
            #expect(set.rpe == 8.5)
            #expect(set.plannedReps == nil)
            #expect(set.rpeSourceRaw == nil)

            record.plannedSetCount = 3
            record.effortSourceRaw = "user"
            set.plannedReps = 6
            set.rpeSourceRaw = "user"
            try context.save()
        }

        let configuration = ModelConfiguration(schema: AppSchema.currentSchema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: AppSchema.currentSchema, configurations: configuration)
        let context = ModelContext(container)
        let record = try #require(context.fetch(FetchDescriptor<ExerciseRecord>()).first)
        #expect(record.plannedSetCount == 3)
        #expect(record.effortSourceRaw == "user")
        let set = try #require(record.sets?.first)
        #expect(set.reps == 5)
        #expect(set.plannedReps == 6)
        #expect(set.rpeSourceRaw == "user")
    }

    @Test("Automatic migration reopens a persisted store")
    func automaticMigrationReopensStore() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }

        // Create a store with the current schema.
        let config = ModelConfiguration(
            schema: AppSchema.currentSchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: AppSchema.currentSchema, configurations: config)

        // Insert a record to verify the store is functional.
        let context = ModelContext(container)
        let record = BodyCompositionRecord(date: Date(), weight: 70)
        context.insert(record)
        try context.save()

        // Reopen — automatic lightweight migration should succeed.
        let reopenConfig = ModelConfiguration(
            schema: AppSchema.currentSchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let reopened = try ModelContainer(for: AppSchema.currentSchema, configurations: reopenConfig)
        let reopenedContext = ModelContext(reopened)
        let fetched = try reopenedContext.fetch(FetchDescriptor<BodyCompositionRecord>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.weight == 70)
    }

    @Test("V18 cardio record migrates and level changes survive reopen")
    func v18CardioLevelHistoryMigrates() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }
        let oldSchema = Schema(AppSchemaV18.models)

        do {
            let configuration = ModelConfiguration(schema: oldSchema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: oldSchema, configurations: configuration)
            let context = ModelContext(container)
            context.insert(AppSchemaV18.ExerciseRecord(
                exerciseType: "stair-climber", duration: 600,
                cardioMachineLevelAverage: 6, cardioMachineLevelMax: 8
            ))
            try context.save()
        }

        let configuration = ModelConfiguration(schema: AppSchema.currentSchema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(for: AppSchema.currentSchema, configurations: configuration)
        let context = ModelContext(container)
        let record = try #require(context.fetch(FetchDescriptor<ExerciseRecord>()).first)
        #expect(record.cardioMachineLevelAverage == 6)
        #expect(record.cardioMachineLevelChanges.isEmpty)
        let changes = [
            try #require(CardioMachineLevelChange(elapsedSeconds: 0, level: 5)),
            try #require(CardioMachineLevelChange(elapsedSeconds: 240, level: 8))
        ]
        record.cardioMachineLevelChangesData = try JSONEncoder().encode(changes)
        try context.save()

        let reopened = try ModelContainer(for: AppSchema.currentSchema, configurations: configuration)
        let saved = try #require(ModelContext(reopened).fetch(FetchDescriptor<ExerciseRecord>()).first)
        #expect(saved.cardioMachineLevelChanges == changes)
    }

    @Test("V19 store migrates to V20 without changing exercise data; location survives reopen")
    func v19LocationMigratesAndReopens() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeStoreFiles(at: storeURL) }
        let oldSchema = Schema(AppSchemaV19.models)
        #expect(oldSchema.entities.count == 13)
        let recordID: UUID
        do {
            let configuration = ModelConfiguration(schema: oldSchema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: oldSchema, configurations: configuration)
            let context = ModelContext(container)
            let record = ExerciseRecord(exerciseType: "running", duration: 600)
            recordID = record.id
            context.insert(record)
            try context.save()
        }
        let configuration = ModelConfiguration(schema: AppSchema.currentSchema, url: storeURL, cloudKitDatabase: .none)
        let place = try #require(WorkoutPlace(latitude: 37, longitude: 127, name: "Gym", source: .manual))
        do {
            let container = try ModelContainer(for: AppSchema.currentSchema, configurations: configuration)
            let context = ModelContext(container)
            let exercise = try #require(context.fetch(FetchDescriptor<ExerciseRecord>()).first)
            #expect(exercise.id == recordID)
            #expect(exercise.duration == 600)
            #expect(try context.fetchCount(FetchDescriptor<WorkoutLocationRecord>()) == 0)
            context.insert(WorkoutLocationRecord(localRecordID: recordID,
                healthKitWorkoutID: "workout-id", payload: WorkoutLocationPayload(isIndoor: true, place: place)))
            try context.save()
        }
        let reopened = try ModelContainer(for: AppSchema.currentSchema, configurations: configuration)
        let location = try #require(ModelContext(reopened).fetch(FetchDescriptor<WorkoutLocationRecord>()).first)
        #expect(location.localRecordID == recordID)
        #expect(location.healthKitWorkoutID == "workout-id")
        #expect(location.payload?.place == place)
        #expect(location.payload?.isIndoor == true)
    }

    @Test("Every V19 entity, relationship and attachment survives an inaccessible store, a writer lock and cold reopen")
    func completeLegacyStoreSurvivesUpgrade() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "original.store")
        let legacy = Schema(AppSchemaV19.models)
        let tables = legacy.entities.map { "Z" + $0.name.uppercased() }.sorted()
        let front = Data(repeating: 0x3a, count: 1_280_003)
        let side = Data(repeating: 0x93, count: 1_024_013)
        let entry = TemplateEntry(exerciseDefinitionID: "test-curl", exerciseName: "Custom curl",
                                  defaultSets: 4, defaultReps: 7, defaultWeightKg: 12.5)
        // Retain value identities alone outside each store lifetime.
        let habitID = UUID()
        let recordID = UUID()
        try autoreleasepool {
            let config = ModelConfiguration(schema: legacy, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: legacy, configurations: config)
            let context = ModelContext(container)
            let exercise = ExerciseRecord(date: .now, exerciseType: "Manual session", duration: 727)
            exercise.id = recordID
            exercise.healthKitWorkoutID = nil
            exercise.memo = "운동 메모"
            let set = WorkoutSet(setNumber: 2, weight: 12.5, reps: 7, isCompleted: true)
            set.exerciseRecord = exercise
            context.insert(exercise)
            context.insert(set)
            let habit = HabitDefinition(name: "Test habit", iconCategory: .health, habitType: .count,
                                       goalValue: 7, goalUnit: "times", frequency: .weekly(targetDays: 3))
            habit.id = habitID
            context.insert(habit)
            let log = HabitLog(date: .now, value: 3, memo: "습관 메모")
            log.habitDefinition = habit
            context.insert(log)
            context.insert(BodyCompositionRecord(weight: 68.7, bodyFatPercentage: 17.25, muscleMass: 29, memo: "체성분"))
            context.insert(InjuryRecord(bodyPart: .knee, bodySide: nil, severity: .minor,
                                        startDate: .now, memo: "회복 메모"))
            context.insert(CustomExercise(name: entry.exerciseName, category: .strength, inputType: .setsRepsWeight,
                                          primaryMuscles: [.biceps], equipment: .bodyweight))
            context.insert(WorkoutTemplate(name: "내 루틴", exerciseEntries: [entry]))
            context.insert(UserCategory(name: "내 분류", colorHex: "2255AA", sortOrder: 2))
            context.insert(ExerciseDefaultRecord(exerciseDefinitionID: entry.exerciseDefinitionID,
                                                 defaultWeight: 12.5, defaultReps: 7, isPreferred: true))
            context.insert(HealthSnapshotMirrorRecord(sourceDevice: "fixture", payloadJSON: "{\"version\":1}"))
            context.insert(HourlyScoreSnapshot(date: .now, conditionScore: 75, readinessScore: 61, hrvValue: 43))
            context.insert(PostureAssessmentRecord(overallScore: 71, frontImageData: front, sideImageData: side,
                                                   bodyHeight: 172, memo: "자세 메모"))
            try context.save()
        }
        let baseline = try legacyRows(at: url, tables: tables)
        #expect(baseline.count == 13)
        func openOriginal() -> PersistentStoreOpening<ModelContainer> {
            PersistentStoreOpening {
                let config = ModelConfiguration(schema: AppSchema.currentSchema, url: url, cloudKitDatabase: .none)
                return try ModelContainer(for: AppSchema.currentSchema, configurations: config)
            }
        }

        // Make only this fixture inaccessible. The production opener must not silently substitute an empty store.
        let files = FileManager.default
        let permissions = try #require(files.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber)
        try files.setAttributes([.posixPermissions: 0], ofItemAtPath: directory.path)
        do {
            defer { try? files.setAttributes([.posixPermissions: permissions], ofItemAtPath: directory.path) }
            try #require(!files.isReadableFile(atPath: url.path))
            #expect(openOriginal().value == nil)
        }
        #expect(try legacyRows(at: url, tables: tables) == baseline)
        try whileStoreIsWriterLocked(at: url) {
            // SwiftData can return an error immediately or wait until the writer releases its lock.
            if let container = openOriginal().value {
                #expect(container.configurations.allSatisfy { !$0.isStoredInMemoryOnly && $0.url == url })
                let records = try ModelContext(container).fetch(FetchDescriptor<ExerciseRecord>())
                #expect(records.map(\.id) == [recordID])
            }
        }
        #expect(try legacyRows(at: url, tables: tables) == baseline)
        for _ in 0..<2 {
            try autoreleasepool {
                let container = try #require(openOriginal().value)
                #expect(container.configurations.allSatisfy { !$0.isStoredInMemoryOnly && $0.url == url })
                let context = ModelContext(container)
                #expect(try context.fetch(FetchDescriptor<WorkoutSet>()).first?.exerciseRecord?.id == recordID)
                #expect(try context.fetch(FetchDescriptor<HabitLog>()).first?.habitDefinition?.id == habitID)
                #expect(try context.fetch(FetchDescriptor<WorkoutTemplate>()).first?.exerciseEntries.first?.id == entry.id)
                let photo = try #require(context.fetch(FetchDescriptor<PostureAssessmentRecord>()).first)
                #expect(photo.frontImageData.map { SHA256.hash(data: $0) } == SHA256.hash(data: front))
                #expect(photo.sideImageData.map { SHA256.hash(data: $0) } == SHA256.hash(data: side))
                #expect(try context.fetchCount(FetchDescriptor<WorkoutLocationRecord>()) == 0)
            }
            #expect(try legacyRows(at: url, tables: tables) == baseline)
        }
    }

    /// Begin opening the store under verified writer contention, then let Core Data retry.
    private func whileStoreIsWriterLocked(at url: URL, perform: () throws -> Void) throws {
        let acquired = DispatchSemaphore(value: 0)
        let opening = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            var writer: OpaquePointer?
            defer {
                sqlite3_close(writer)
                finished.signal()
            }
            guard sqlite3_open_v2(url.path, &writer, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else { return }
            sqlite3_busy_timeout(writer, 2_000)
            guard sqlite3_exec(writer, "PRAGMA locking_mode=EXCLUSIVE; BEGIN EXCLUSIVE", nil, nil, nil) == SQLITE_OK
            else { return }
            acquired.signal()
            _ = opening.wait(timeout: .now() + 5)
            _ = release.wait(timeout: .now() + 2)
            sqlite3_exec(writer, "ROLLBACK", nil, nil, nil)
        }
        defer {
            opening.signal()
            release.signal()
            #expect(finished.wait(timeout: .now() + 5) == .success)
        }
        try #require(acquired.wait(timeout: .now() + 5) == .success)

        var probe: OpaquePointer?
        defer { sqlite3_close(probe) }
        try #require(sqlite3_open_v2(url.path, &probe, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK)
        sqlite3_busy_timeout(probe, 0)
        try #require(sqlite3_exec(probe, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_BUSY)
        opening.signal()
        try perform()
    }

    /// Reads only this synthetic fixture, comparing every persisted value independently of SQLite column order.
    /// To-one relationships use the parent's domain UUID instead of SQLite's internal row number.
    private func legacyRows(at url: URL, tables: [String]) throws -> [String: [String: SHA256.Digest]] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_close(database) }
        // Core Data can still be checkpointing the sidecars after the old stack closes.
        sqlite3_busy_timeout(database, 5_000)
        func queryError(_ sql: String) -> NSError {
            NSError(domain: "LegacyMigrationFixture", code: Int(sqlite3_errcode(database)),
                    userInfo: [NSLocalizedDescriptionKey: "\(String(cString: sqlite3_errmsg(database))) [\(sql)]"])
        }
        func rows(_ sql: String, visit: (OpaquePointer) throws -> Void) throws {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
                throw queryError(sql)
            }
            defer { sqlite3_finalize(statement) }
            var step = sqlite3_step(statement)
            while step == SQLITE_ROW {
                try visit(statement)
                step = sqlite3_step(statement)
            }
            guard step == SQLITE_DONE else { throw queryError(sql) }
        }
        try rows("BEGIN") { _ in }
        var snapshot = [String: [String: SHA256.Digest]]()
        for table in tables {
            var fields = [String]()
            try rows("PRAGMA table_info(\(table))") { row in
                let column = String(cString: sqlite3_column_text(row, 1))
                if !["Z_PK", "Z_ENT", "Z_OPT"].contains(column) { fields.append(column) }
            }
            let select = fields.map { column in
                if ["ZEXERCISERECORD", "ZHABITDEFINITION"].contains(column) {
                    return "(SELECT parent.ZID FROM \(column) AS parent WHERE parent.Z_PK = child.\(column))"
                }
                return "child.\(column)"
            }
            var count = 0
            try rows("SELECT \(select.joined(separator: ", ")) FROM \(table) AS child") { row in
                count += 1
                var values = [String: SHA256.Digest]()
                for (index, name) in fields.enumerated() {
                    let column = Int32(index)
                    let kind = sqlite3_column_type(row, column)
                    var value = Data([UInt8(kind)])
                    switch kind {
                    case SQLITE_INTEGER:
                        withUnsafeBytes(of: sqlite3_column_int64(row, column).littleEndian) { value.append(contentsOf: $0) }
                    case SQLITE_FLOAT:
                        withUnsafeBytes(of: sqlite3_column_double(row, column).bitPattern.littleEndian) { value.append(contentsOf: $0) }
                    case SQLITE_BLOB, SQLITE_TEXT:
                        if let bytes = sqlite3_column_blob(row, column) {
                            value.append(bytes.assumingMemoryBound(to: UInt8.self), count: Int(sqlite3_column_bytes(row, column)))
                        }
                    default: break
                    }
                    values[name] = SHA256.hash(data: value)
                }
                snapshot[table] = values
            }
            // Each V19 entity is deliberately populated once.
            #expect(count == 1)
        }
        try rows("COMMIT") { _ in }
        return snapshot
    }

    private func makeTemporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
    }

    private func removeStoreFiles(at url: URL) {
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
