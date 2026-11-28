import CryptoKit
import SQLite3
import CloudKit
import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("Legacy workout recovery")
@MainActor
struct LegacyWorkoutRecoveryTests {
    private func store() throws -> ModelContainer {
        let schema = Schema([ExerciseRecord.self, WorkoutSet.self, WorkoutLocationRecord.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        ))
    }

    private func workout() -> CKRecord {
        let record = CKRecord(recordType: "CD_ExerciseRecord")
        record["CD_id"] = UUID().uuidString
        record["CD_date"] = Date(timeIntervalSince1970: 100)
        record["CD_createdAt"] = Date(timeIntervalSince1970: 200)
        record["CD_exerciseType"] = "Walking"
        record["CD_duration"] = NSNumber(value: 60)
        return record
    }

    private func set(parent: CKRecord) -> CKRecord {
        let record = CKRecord(recordType: "CD_WorkoutSet")
        record["CD_id"] = UUID().uuidString
        record["CD_exerciseRecord"] = parent.recordID.recordName
        record["CD_setNumber"] = NSNumber(value: 1)
        record["CD_reps"] = NSNumber(value: 8)
        return record
    }

    @Test func restoresHistoricalLocationAndPreservesLocalEdits() throws {
        let container = try store()
        let exercise = workout()
        let record = CKRecord(recordType: "CD_WorkoutLocationRecord")
        let healthID = UUID().uuidString
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let place = try #require(WorkoutPlace(latitude: 12, longitude: 22, name: "Fixture gym", source: .manual))
        let route = try #require(WorkoutRoutePoint(latitude: 12.1, longitude: 22.1, timestamp: stamp))
        let payload = WorkoutLocationPayload(isIndoor: true, route: [route], place: place)
        record["CD_id"] = UUID().uuidString
        record["CD_localRecordID"] = exercise["CD_id"]
        record["CD_healthKitWorkoutID"] = healthID
        record["CD_updatedAt"] = stamp
        let bytes = try JSONEncoder().encode(payload)
        let file = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try bytes.write(to: file)
        record["CD_payloadData_ckAsset"] = CKAsset(fileURL: file)
        let first = try LegacyWorkoutRecovery.importRecords([record, exercise], into: container)
        #expect(first.locations == 1)
        let context = ModelContext(container)
        let row = try #require(context.fetch(FetchDescriptor<WorkoutLocationRecord>()).first)
        #expect(row.localRecordID?.uuidString == exercise["CD_id"] as? String)
        #expect(row.healthKitWorkoutID == healthID)
        #expect(row.payloadData == bytes && row.updatedAt == stamp)
        #expect(row.payload == payload)
        #expect(try LegacyWorkoutRecovery.importRecords([record, exercise], into: container).locations == 0)
        row.payload = WorkoutLocationPayload(isIndoor: true)
        try context.save()
        #expect(throws: LegacyWorkoutRecovery.Failure.localConflict) {
            try LegacyWorkoutRecovery.importRecords([workout(), record], into: container)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 1)
        #expect(try ModelContext(container).fetch(FetchDescriptor<WorkoutLocationRecord>()).first?.payload?.place == nil)
    }

    @Test func mixedVersionRecoveryRetainsNewerFieldsAndFillsOnlyMissingValues() throws {
        let container = try store()
        let original = workout(), trainingSet = set(parent: original)
        original["CD_plannedSetCount"] = NSNumber(value: 4)
        trainingSet["CD_rpeSourceRaw"] = "manual"
        _ = try LegacyWorkoutRecovery.importRecords([original, trainingSet], into: container)

        original["CD_plannedSetCount"] = nil
        trainingSet["CD_rpeSourceRaw"] = nil
        original["CD_effortSourceRaw"] = "user"
        trainingSet["CD_plannedReps"] = NSNumber(value: 8)
        let extra = workout()
        let records = [original, trainingSet, extra]
        #expect(try LegacyWorkoutRecovery.importRecords(records, into: container).workouts == 1)
        #expect(try LegacyWorkoutRecovery.importRecords(records, into: container).workouts == 0)
        let context = ModelContext(container)
        let set = try #require(context.fetch(FetchDescriptor<WorkoutSet>()).first)
        #expect(set.rpeSourceRaw == "manual" && set.plannedReps == 8)
        #expect(set.exerciseRecord?.plannedSetCount == 4 && set.exerciseRecord?.effortSourceRaw == "user")

        trainingSet["CD_plannedReps"] = NSNumber(value: 10)
        #expect(throws: LegacyWorkoutRecovery.Failure.localConflict) {
            try LegacyWorkoutRecovery.importRecords([workout()] + records, into: container)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 2)
        #expect(try ModelContext(container).fetch(FetchDescriptor<WorkoutSet>()).first?.plannedReps == 8)
    }

    @Test func resolvesParentsAcrossPagesAndRepeatedImports() throws {
        let container = try store()
        let first = workout(), second = workout()
        let pages = [[set(parent: second)], [first, set(parent: first)], [second]]
        let records = pages.flatMap { $0 }
        let added = try LegacyWorkoutRecovery.importRecords(records, into: container)
        #expect(added.workouts == 2 && added.sets == 2)
        let repeatResult = try LegacyWorkoutRecovery.importRecords(records, into: container)
        #expect(repeatResult.workouts == 0 && repeatResult.sets == 0)
        let sets = try ModelContext(container).fetch(FetchDescriptor<WorkoutSet>())
        #expect(Set(sets.compactMap { $0.exerciseRecord?.id }).count == 2)
        #expect(sets.allSatisfy { $0.reps == 8 })
    }

    @Test func retainsSeparateExercisesLinkedToOneHealthKitSession() throws {
        let container = try store()
        let first = workout(), second = workout()
        let healthID = UUID().uuidString
        first["CD_healthKitWorkoutID"] = healthID
        second["CD_healthKitWorkoutID"] = healthID.lowercased()
        _ = try LegacyWorkoutRecovery.importRecords([first], into: container)
        let result = try LegacyWorkoutRecovery.importRecords([first, second], into: container)
        #expect(result.workouts == 1)
        let count = try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>())
        #expect(count == 2)
        let repeated = try LegacyWorkoutRecovery.importRecords([second, first], into: container)
        #expect(repeated.workouts == 0)
    }

    @Test func rejectsIdentifiersAlreadyDuplicatedOnDevice() throws {
        let container = try store()
        let context = ModelContext(container)
        let domainID = UUID()
        for _ in 0..<2 {
            let row = ExerciseRecord(date: .now, exerciseType: "Walking", duration: 30)
            row.id = domainID
            context.insert(row)
        }
        try context.save()
        #expect(throws: LegacyWorkoutRecovery.Failure.duplicateIdentity) {
            try LegacyWorkoutRecovery.importRecords([workout()], into: container)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 2)
    }

    @Test func orphanRollsBackEarlierInsertions() throws {
        let container = try store()
        #expect(throws: LegacyWorkoutRecovery.Failure.invalidRelationship) {
            try LegacyWorkoutRecovery.importRecords([workout(), set(parent: workout())], into: container)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 0)
    }

    @Test func preservesLocalAndRemoteEditsOnConflict() throws {
        let container = try store()
        let source = workout(), child = set(parent: source)
        _ = try LegacyWorkoutRecovery.importRecords([source, child], into: container)
        let context = ModelContext(container)
        let local = try #require(context.fetch(FetchDescriptor<ExerciseRecord>()).first)
        local.memo = "device edit"
        try context.save()
        source["CD_memo"] = "cloud edit"
        #expect(throws: LegacyWorkoutRecovery.Failure.localConflict) {
            try LegacyWorkoutRecovery.importRecords([workout(), source, child], into: container)
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<ExerciseRecord>()).map(\.memo) == ["device edit"])
        #expect(source["CD_memo"] as? String == "cloud edit")
        source["CD_memo"] = "device edit"
        child["CD_reps"] = NSNumber(value: 9)
        #expect(throws: LegacyWorkoutRecovery.Failure.localConflict) {
            try LegacyWorkoutRecovery.importRecords([source, child], into: container)
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<WorkoutSet>()).first?.reps == 8)
    }

    @Test func refusesMalformedOptionalNumbersAndBinaryAssets() throws {
        let container = try store()
        let record = workout()
        record["CD_distance"] = "5"
        #expect(throws: LegacyWorkoutRecovery.Failure.invalidRecord) {
            try LegacyWorkoutRecovery.importRecords([record], into: container)
        }
        record["CD_distance"] = nil
        record["CD_stepCount"] = NSNumber(value: 2.5)
        #expect(throws: LegacyWorkoutRecovery.Failure.invalidRecord) {
            try LegacyWorkoutRecovery.importRecords([record], into: container)
        }
        record["CD_stepCount"] = nil
        record["CD_cardioMachineLevelChangesData_ckAsset"] = "invalid asset"
        #expect(throws: LegacyWorkoutRecovery.Failure.invalidRecord) {
            try LegacyWorkoutRecovery.importRecords([record], into: container)
        }
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExerciseRecord>()) == 0)
    }
}

@Suite("Historical iCloud Settings recovery", .serialized)
@MainActor
struct HistoricalSettingsRecoveryTests {
    private let stamp = Date(timeIntervalSince1970: 1_700_002_800)

    private func diskStore(_ url: URL) throws -> ModelContainer {
        let schema = AppSchema.currentSchema
        return try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, url: url, cloudKitDatabase: .none
        ))
    }

    private func old(_ entity: String, _ values: [String: CKRecordValue], id: Bool = true) -> CKRecord {
        let row = CKRecord(recordType: "CD_" + entity)
        if id { row["CD_id"] = UUID().uuidString }
        for (key, value) in values { row["CD_" + key] = value }
        return row
    }

    /// SwiftData chooses its own transformable serialization. Read only the isolated fixture store.
    private func sourceTransformables(at url: URL, entry: TemplateEntry) throws -> (Data, Data, Data) {
        try autoreleasepool {
            let container = try diskStore(url)
            let context = container.mainContext
            let custom = CustomExercise(name: "Fixture lift", category: .strength, inputType: .setsRepsWeight,
                                        primaryMuscles: [], equipment: .bodyweight)
            custom.primaryMusclesRaw = ["chest"]
            custom.secondaryMusclesRaw = ["triceps"]
            context.insert(custom)
            context.insert(WorkoutTemplate(name: "Fixture plan", exerciseEntries: [entry]))
            try context.save()
        }
        var db: OpaquePointer?
        let status = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil)
        defer { sqlite3_close(db) }
        try #require(status == SQLITE_OK)
        // The writer may still hold the WAL checkpoint lock while the container is closing.
        sqlite3_busy_timeout(db, 5_000)
        func bytes(_ sql: String) throws -> Data {
            var query: OpaquePointer?
            let status = sqlite3_prepare_v2(db, sql, -1, &query, nil)
            defer { sqlite3_finalize(query) }
            try #require(status == SQLITE_OK)
            try #require(sqlite3_step(query) == SQLITE_ROW)
            let pointer = try #require(sqlite3_column_blob(query, 0))
            let size = Int(sqlite3_column_bytes(query, 0))
            try #require(size > 0)
            return Data(bytes: pointer, count: size)
        }
        return try (bytes("SELECT ZEXERCISEENTRIES FROM ZWORKOUTTEMPLATE"),
                    bytes("SELECT ZPRIMARYMUSCLESRAW FROM ZCUSTOMEXERCISE"),
                    bytes("SELECT ZSECONDARYMUSCLESRAW FROM ZCUSTOMEXERCISE"))
    }

    private func fixture(photoURL: URL) throws -> [CKRecord] {
        let exercise = old("ExerciseRecord", ["date": stamp as NSDate, "createdAt": stamp as NSDate,
                                              "exerciseType": "Stair Climbing" as NSString, "duration": 90 as NSNumber])
        let set = old("WorkoutSet", ["exerciseRecord": exercise.recordID.recordName as NSString, "setNumber": 1 as NSNumber,
                                    "reps": 6 as NSNumber, "isCompleted": true as NSNumber])
        let place = try #require(WorkoutPlace(latitude: 1, longitude: 2, name: "Synthetic gym", source: .manual))
        let localID = try #require(exercise["CD_id"] as? NSString)
        let location = old("WorkoutLocationRecord", ["localRecordID": localID, "updatedAt": stamp as NSDate,
                              "payloadData": try JSONEncoder().encode(WorkoutLocationPayload(isIndoor: true, place: place)) as NSData])
        let body = old("BodyCompositionRecord", ["date": stamp as NSDate, "createdAt": stamp as NSDate,
                                                  "weight": 63.5 as NSNumber, "memo": "Fixture body" as NSString])
        let category = old("UserCategory", ["name": "Fixture category" as NSString, "createdAt": stamp as NSDate,
                                           "iconName": "tag" as NSString, "colorHex": "112233" as NSString])
        let custom = old("CustomExercise", ["name": "Fixture lift" as NSString, "categoryRaw": "strength" as NSString,
                                          "inputTypeRaw": "setsRepsWeight" as NSString, "equipmentRaw": "bodyweight" as NSString,
                                          "customCategoryName": "Fixture category" as NSString, "createdAt": stamp as NSDate])
        let customID = try #require(custom["CD_id"] as? String)
        let entry = TemplateEntry(exerciseDefinitionID: customID, exerciseName: "Fixture lift", defaultWeightKg: 17)
        let buffers = try sourceTransformables(at: photoURL.deletingLastPathComponent().appendingPathComponent("source.store"),
                                              entry: entry)
        custom["CD_primaryMusclesRaw"] = buffers.1 as NSData
        custom["CD_secondaryMusclesRaw"] = buffers.2 as NSData
        let template = old("WorkoutTemplate", ["name": "Fixture plan" as NSString, "createdAt": stamp as NSDate,
                                             "updatedAt": stamp as NSDate, "exerciseEntries": buffers.0 as NSData])
        let injury = old("InjuryRecord", ["bodyPartRaw": "knee" as NSString, "severityRaw": 2 as NSNumber,
                                         "startDate": stamp as NSDate, "createdAt": stamp as NSDate, "memo": "Fixture injury" as NSString])
        let habit = old("HabitDefinition", ["name": "Fixture habit" as NSString, "createdAt": stamp as NSDate,
                                          "goalValue": 2 as NSNumber, "goalUnit": "cups" as NSString])
        let log = old("HabitLog", ["date": stamp as NSDate, "value": 2 as NSNumber, "memo": "Fixture log" as NSString,
                                  "habitDefinition": CKRecord.Reference(recordID: habit.recordID, action: .none)])
        let favorite = old("ExerciseDefaultRecord", ["exerciseDefinitionID": customID as NSString, "defaultWeight": 17 as NSNumber,
                                                   "lastUsedDate": stamp as NSDate, "isPreferred": true as NSNumber])
        let posture = old("PostureAssessmentRecord", ["date": stamp as NSDate, "createdAt": stamp as NSDate,
                                                    "overallScore": 72 as NSNumber, "frontImageData_ckAsset": CKAsset(fileURL: photoURL),
                                                    "memo": "Fixture posture" as NSString])
        let hourly = old("HourlyScoreSnapshot", ["date": stamp as NSDate, "createdAt": stamp as NSDate,
                                               "conditionScore": 74 as NSNumber, "stressScore": 22 as NSNumber], id: false)
        let payload = HealthSnapshotMirrorMapper.Payload(
            fetchedAt: stamp, failedSources: [], todayRHR: nil, yesterdayRHR: nil, latestRHR: nil, hrv14Day: [],
            rhr14Day: [], sleep14Day: [], todaySleepMinutes: 0, yesterdaySleepMinutes: 0, conditionScore: nil,
            conditionStatus: nil, conditionContributions: nil, conditionDetail: nil, baselineReady: nil,
            baselineProgress: nil, recentScores: [], todaySteps: 777
        )
        let mirror = old("HealthSnapshotMirrorRecord", ["fetchedAt": stamp as NSDate, "syncedAt": stamp as NSDate,
                                                       "sourceDevice": "Fixture" as NSString, "payloadVersion": 1 as NSNumber,
                                                       "payloadJSON": try HealthSnapshotMirrorMapper.encode(payload) as NSString])
        return [log, set, template, location, mirror, body, posture, custom, category, favorite, injury, habit, hourly, exercise]
    }

    private func throughSettings(_ records: [CKRecord], into container: ModelContainer) async throws -> LegacyWorkoutRecovery.Result {
        let settings = SettingsWorkoutRecovery()
        var outcome: LegacyWorkoutRecovery.Result?
        await settings.restore {
            let result = try await LegacyWorkoutRecovery.restore(into: container, fetchRecords: { records })
            outcome = result
            return result
        }
        #expect(!settings.isRestoring)
        #expect(settings.message?.isEmpty == false)
        return try #require(outcome)
    }

    @Test func settingsRestoresHistoricalZoneColdAndRejectsPartialFailures() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let target = folder.appendingPathComponent("receiver.store")
        let photoURL = folder.appendingPathComponent("original.png")
        let photo = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aZS8AAAAASUVORK5CYII="))
        try photo.write(to: photoURL)
        let records = try fixture(photoURL: photoURL)
        let byType = Dictionary(uniqueKeysWithValues: records.map { ($0.recordType, $0) })
        func id(_ entity: String) -> String? { byType["CD_" + entity]?["CD_id"] as? String }
        do {
            let first = try await throughSettings(records, into: diskStore(target))
            #expect(first.workouts == 1 && first.sets == 1 && first.locations == 1 && first.otherRecords == 11)
        }

        let reopened = try diskStore(target)
        let c = reopened.mainContext
        let workout = try #require(c.fetch(FetchDescriptor<ExerciseRecord>()).first)
        #expect(workout.id.uuidString == id("ExerciseRecord") && workout.completedSets.first?.reps == 6)
        let set = try #require(c.fetch(FetchDescriptor<WorkoutSet>()).first)
        #expect(set.id.uuidString == id("WorkoutSet") && set.exerciseRecord?.id == workout.id)
        let pin = try #require(c.fetch(FetchDescriptor<WorkoutLocationRecord>()).first)
        #expect(pin.localRecordID == workout.id && pin.payload?.place?.name == "Synthetic gym")
        let body = try #require(c.fetch(FetchDescriptor<BodyCompositionRecord>()).first)
        #expect(body.id.uuidString == id("BodyCompositionRecord") && body.weight == 63.5 && body.memo == "Fixture body")
        let custom = try #require(c.fetch(FetchDescriptor<CustomExercise>()).first)
        #expect(custom.id.uuidString == id("CustomExercise") && custom.primaryMusclesRaw == ["chest"] && custom.secondaryMusclesRaw == ["triceps"])
        let entry = try #require(c.fetch(FetchDescriptor<WorkoutTemplate>()).first?.exerciseEntries.first)
        #expect(entry.exerciseDefinitionID == custom.id.uuidString && entry.defaultWeightKg == 17)
        let category = try #require(c.fetch(FetchDescriptor<UserCategory>()).first)
        #expect(category.id.uuidString == id("UserCategory") && category.name == custom.customCategoryName && category.colorHex == "112233")
        let injury = try #require(c.fetch(FetchDescriptor<InjuryRecord>()).first)
        #expect(injury.id.uuidString == id("InjuryRecord") && injury.startDate == stamp && injury.endDate == nil && injury.bodyPartRaw == "knee")
        let log = try #require(c.fetch(FetchDescriptor<HabitLog>()).first)
        let habit = try #require(log.habitDefinition)
        #expect(log.id.uuidString == id("HabitLog") && habit.id.uuidString == id("HabitDefinition") && habit.logs?.map(\.id) == [log.id])
        #expect(log.memo == "Fixture log" && log.completedAt == nil)
        #expect(habit.goalUnit == "cups" && habit.weeklyTargetDays == 3)
        let favorite = try #require(c.fetch(FetchDescriptor<ExerciseDefaultRecord>()).first)
        #expect(favorite.id.uuidString == id("ExerciseDefaultRecord") && favorite.exerciseDefinitionID == custom.id.uuidString && favorite.isPreferred)
        let portrait = try #require(c.fetch(FetchDescriptor<PostureAssessmentRecord>()).first)
        let image = try #require(portrait.frontImageData)
        #expect(Data(SHA256.hash(data: image)) == Data(SHA256.hash(data: photo)))
        #expect(portrait.id.uuidString == id("PostureAssessmentRecord") && portrait.sideImageData == nil && portrait.overallScore == 72)
        let hourly = try #require(c.fetch(FetchDescriptor<HourlyScoreSnapshot>()).first)
        #expect(hourly.date == stamp && hourly.conditionScore == 74 && hourly.stressScore == 22)
        let mirror = try #require(c.fetch(FetchDescriptor<HealthSnapshotMirrorRecord>()).first)
        #expect(mirror.id.uuidString == id("HealthSnapshotMirrorRecord") && mirror.fetchedAt == stamp)
        #expect(try HealthSnapshotMirrorMapper.decode(mirror.payloadJSON).todaySteps == 777)
        let replay = try await throughSettings(Array(records.reversed()), into: reopened)
        #expect(replay.workouts == 0 && replay.sets == 0 && replay.locations == 0 && replay.otherRecords == 0)

        let originalBody = try #require(byType["CD_BodyCompositionRecord"])
        let historicLog = try #require(byType["CD_HabitLog"])
        let historicPhoto = try #require(byType["CD_PostureAssessmentRecord"])
        // Earlier CloudKit schema did not emit these keys. A new receiver already has richer values.
        originalBody["CD_weight"] = nil
        historicPhoto["CD_frontImageData_ckAsset"] = nil
        let older = try await throughSettings(records, into: reopened)
        #expect(older.otherRecords == 0)
        let olderRead = ModelContext(reopened)
        #expect(try olderRead.fetch(FetchDescriptor<BodyCompositionRecord>()).first?.weight == 63.5)
        #expect(try olderRead.fetch(FetchDescriptor<PostureAssessmentRecord>()).first?.frontImageData == photo)
        originalBody["CD_weight"] = 63.5 as NSNumber
        historicPhoto["CD_frontImageData_ckAsset"] = CKAsset(fileURL: photoURL)
        let parent = historicLog["CD_habitDefinition"]
        let originalPhoto = historicPhoto["CD_frontImageData_ckAsset"]
        for fault in 0..<4 {
            switch fault {
            case 0: originalBody["CD_weight"] = 77 as NSNumber
            case 1: historicLog["CD_habitDefinition"] = CKRecord.Reference(recordID: CKRecord.ID(recordName: "missing-habit"), action: .none)
            case 2: historicPhoto["CD_frontImageData_ckAsset"] = "unreadable"
            default:
                let zone = CKRecordZone.ID(zoneName: "different-synthetic-zone", ownerName: CKCurrentUserDefaultName)
                let other = CKRecord.ID(recordName: try #require(byType["CD_HabitDefinition"]).recordID.recordName, zoneID: zone)
                historicLog["CD_habitDefinition"] = CKRecord.Reference(recordID: other, action: .none)

            }
            let extra = old("ExerciseRecord", ["date": stamp as NSDate, "createdAt": stamp as NSDate,
                                              "exerciseType": "Additional" as NSString, "duration": 42 as NSNumber])
            let settings = SettingsWorkoutRecovery()
            var returned = false
            await settings.restore {
                let result = try await LegacyWorkoutRecovery.restore(into: reopened, fetchRecords: { [extra] + records })
                returned = true
                return result
            }
            #expect(!returned && !settings.isRestoring && settings.message?.isEmpty == false)
            originalBody["CD_weight"] = 63.5 as NSNumber
            historicLog["CD_habitDefinition"] = parent
            historicPhoto["CD_frontImageData_ckAsset"] = originalPhoto
            let clean = ModelContext(reopened)
            #expect(try clean.fetchCount(FetchDescriptor<ExerciseRecord>()) == 1)
            #expect(try clean.fetch(FetchDescriptor<BodyCompositionRecord>()).first?.weight == 63.5)
            #expect(try clean.fetch(FetchDescriptor<HabitLog>()).first?.habitDefinition?.id == habit.id)
            #expect(try clean.fetch(FetchDescriptor<PostureAssessmentRecord>()).first?.frontImageData == photo)
        }
    }
}

@Suite("Historical CloudKit field round-trip")
@MainActor
struct HistoricalCloudFieldRoundTripTests {
    private func container() throws -> ModelContainer {
        let schema = AppSchema.currentSchema
        return try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        ))
    }

    @Test func fetchFilterIncludesAllFourteenHistoricalEntities() {
        let names: Set<String> = [
            "CD_ExerciseRecord", "CD_WorkoutSet", "CD_WorkoutLocationRecord", "CD_HealthSnapshotMirrorRecord",
            "CD_BodyCompositionRecord", "CD_CustomExercise", "CD_WorkoutTemplate", "CD_InjuryRecord",
            "CD_HabitDefinition", "CD_HabitLog", "CD_UserCategory", "CD_ExerciseDefaultRecord",
            "CD_HourlyScoreSnapshot", "CD_PostureAssessmentRecord",
        ]
        #expect(LegacyWorkoutRecovery.recordTypes == names)
    }

    @Test func restoresBothPostureViewsAndInjuryDatesAndRejectsConflictingOrMalformedAssetsAtomically() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let front = Data([0xAB, 0xCD, 0x11]), side = Data([0x7F, 0x21, 0xEF, 0x16])
        let frontURL = root.appendingPathComponent("front"), sideURL = root.appendingPathComponent("side")
        try front.write(to: frontURL)
        try side.write(to: sideURL)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let created = date.addingTimeInterval(120)
        let source = PostureAssessmentRecord(
            date: date, overallScore: 78,
            frontMetrics: [.init(type: .shoulderAsymmetry, value: 1.4, unit: .centimeters, status: .normal, score: 91, confidence: 0.92)],
            sideMetrics: [.init(type: .forwardHead, value: 8.5, unit: .degrees, status: .caution, score: 63, confidence: 0.89)],
            frontJointPositions: [.init(name: "leftShoulder", position: SIMD3<Float>(0.23, 0.45, 0.02))],
            sideJointPositions: [.init(name: "rightEar", position: SIMD3<Float>(0.17, 0.67, 0.13))],
            frontImageData: front, sideImageData: side, bodyHeight: 1.74, heightEstimation: .measured, memo: "Fixture posture notes"
        )
        source.createdAt = created
        let posture = CKRecord(recordType: "CD_PostureAssessmentRecord")
        posture["CD_id"] = source.id.uuidString
        posture["CD_date"] = date
        posture["CD_createdAt"] = created
        posture["CD_overallScore"] = NSNumber(value: source.overallScore)
        posture["CD_frontMetricsJSON"] = source.frontMetricsJSON
        posture["CD_sideMetricsJSON"] = source.sideMetricsJSON
        posture["CD_frontJointPositionsJSON"] = source.frontJointPositionsJSON
        posture["CD_sideJointPositionsJSON"] = source.sideJointPositionsJSON
        posture["CD_frontImageData_ckAsset"] = CKAsset(fileURL: frontURL)
        posture["CD_sideImageData_ckAsset"] = CKAsset(fileURL: sideURL)
        posture["CD_bodyHeight"] = NSNumber(value: 1.74)
        posture["CD_heightEstimationRaw"] = source.heightEstimationRaw
        posture["CD_memo"] = source.memo

        let injury = InjuryRecord(bodyPart: .knee, bodySide: .left, severity: .moderate,
                                  startDate: date, endDate: date.addingTimeInterval(15_000), memo: "Fixture injury notes")
        injury.createdAt = date.addingTimeInterval(60)
        func cloudInjury(_ id: UUID) -> CKRecord {
            let record = CKRecord(recordType: "CD_InjuryRecord")
            record["CD_id"] = id.uuidString
            record["CD_bodyPartRaw"] = injury.bodyPartRaw
            record["CD_bodySideRaw"] = injury.bodySideRaw
            record["CD_severityRaw"] = NSNumber(value: injury.severityRaw)
            record["CD_startDate"] = injury.startDate
            record["CD_endDate"] = injury.endDate
            record["CD_createdAt"] = injury.createdAt
            record["CD_memo"] = injury.memo
            return record
        }
        let store = try container()
        let first = try LegacyWorkoutRecovery.importRecords([posture, cloudInjury(injury.id)], into: store)
        #expect(first.otherRecords == 2)
        let read = ModelContext(store)
        let restored = try #require(read.fetch(FetchDescriptor<PostureAssessmentRecord>()).first)
        #expect(restored.id == source.id && restored.date == date && restored.createdAt == created)
        #expect(restored.overallScore == source.overallScore && restored.memo == source.memo)
        #expect(restored.heightEstimation == .measured && restored.bodyHeight == source.bodyHeight)
        #expect(restored.frontMetricsJSON == source.frontMetricsJSON && restored.sideMetricsJSON == source.sideMetricsJSON)
        #expect(restored.frontJointPositionsJSON == source.frontJointPositionsJSON && restored.sideJointPositionsJSON == source.sideJointPositionsJSON)
        #expect(restored.frontImageData == front && restored.sideImageData == side)
        let restoredInjury = try #require(read.fetch(FetchDescriptor<InjuryRecord>()).first)
        #expect(restoredInjury.id == injury.id && restoredInjury.bodyPartRaw == injury.bodyPartRaw && restoredInjury.bodySideRaw == injury.bodySideRaw)
        #expect(restoredInjury.severityRaw == injury.severityRaw && restoredInjury.memo == injury.memo)
        #expect(restoredInjury.startDate == injury.startDate && restoredInjury.endDate == injury.endDate && restoredInjury.createdAt == injury.createdAt)

        // Changing only the transport does not change the underlying attachment.
        posture["CD_frontImageData_ckAsset"] = nil
        posture["CD_frontImageData"] = front
        let repeated = try LegacyWorkoutRecovery.importRecords([posture, cloudInjury(injury.id)], into: store)
        #expect(repeated.otherRecords == 0)
        let newInjury = cloudInjury(UUID())
        let changedURL = root.appendingPathComponent("different-side")
        try Data([3, 2, 1]).write(to: changedURL)
        posture["CD_sideImageData_ckAsset"] = CKAsset(fileURL: changedURL)
        #expect(throws: LegacyWorkoutRecovery.Failure.localConflict) {
            try LegacyWorkoutRecovery.importRecords([newInjury, posture], into: store)
        }
        posture["CD_sideImageData"] = side // ambiguous: both inline and asset
        #expect(throws: LegacyWorkoutRecovery.Failure.invalidRecord) {
            try LegacyWorkoutRecovery.importRecords([newInjury, posture], into: store)
        }
        posture["CD_sideImageData"] = nil
        let sparse = root.appendingPathComponent("oversized")
        try Data().write(to: sparse)
        let file = try FileHandle(forWritingTo: sparse)
        try file.truncate(atOffset: 32 * 1024 * 1024 + 1)
        try file.close()
        posture["CD_sideImageData_ckAsset"] = CKAsset(fileURL: sparse)
        #expect(throws: LegacyWorkoutRecovery.Failure.invalidRecord) {
            try LegacyWorkoutRecovery.importRecords([newInjury, posture], into: store)
        }
        let check = ModelContext(store)
        #expect(try check.fetchCount(FetchDescriptor<InjuryRecord>()) == 1)
        #expect(try check.fetchCount(FetchDescriptor<PostureAssessmentRecord>()) == 1)
        let afterFailure = try #require(check.fetch(FetchDescriptor<PostureAssessmentRecord>()).first)
        #expect(afterFailure.frontImageData == front && afterFailure.sideImageData == side)
    }
}
