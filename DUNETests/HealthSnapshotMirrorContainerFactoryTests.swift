import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("HealthSnapshotMirrorContainerFactory")
struct HealthSnapshotMirrorContainerFactoryTests {
    @Test("prefers cloud sync opt-in when cloud state exists")
    func prefersCloudValueWhenPresent() {
        let resolved = CloudSyncPreferenceStore.resolve(localValue: true, cloudValue: false)

        #expect(resolved == false)
    }

    @Test("falls back to local sync opt-in when cloud state is missing")
    func fallsBackToLocalValueWhenCloudMissing() {
        let resolved = CloudSyncPreferenceStore.resolve(localValue: true, cloudValue: nil)

        #expect(resolved == true)
    }

    @Test("seeds cloud state only for explicit local opt-in when cloud state is missing")
    func seedsCloudStateOnlyForLocalOptIn() {
        let optInSeed = CloudSyncPreferenceStore.cloudSeedValue(localValue: true, cloudValue: nil)
        let optOutSeed = CloudSyncPreferenceStore.cloudSeedValue(localValue: false, cloudValue: nil)
        let unsetSeed = CloudSyncPreferenceStore.cloudSeedValue(localValue: nil, cloudValue: nil)
        let existingCloudSeed = CloudSyncPreferenceStore.cloudSeedValue(localValue: true, cloudValue: false)

        #expect(optInSeed == true)
        #expect(optOutSeed == nil)
        #expect(unsetSeed == nil)
        #expect(existingCloudSeed == nil)
    }

    @Test("runtime refresh action rebuilds when resolved cloud sync value changes")
    func runtimeRefreshActionRebuildsWhenResolvedValueChanges() {
        let action = CloudSyncPreferenceStore.runtimeRefreshAction(
            currentValue: false,
            localValue: false,
            cloudValue: true
        )

        #expect(action == .rebuild(resolvedValue: true))
    }

    @Test("runtime refresh action stays in place when resolved cloud sync value is unchanged")
    func runtimeRefreshActionSkipsRebuildWhenValueMatches() {
        let action = CloudSyncPreferenceStore.runtimeRefreshAction(
            currentValue: true,
            localValue: true,
            cloudValue: nil
        )

        #expect(action == .noChange(resolvedValue: true))
    }

    @Test("health snapshot storage always stays local")
    func snapshotStoreStaysLocal() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")

        let configuration = HealthSnapshotMirrorContainerFactory.configuration(
            url: url
        )

        #expect(isCloudKitDisabled(configuration.cloudKitDatabase))
        #expect(configuration.url == url)
    }

    @Test("uses mirror-only schema in an in-memory container")
    func usesMirrorOnlySchemaInMemory() throws {
        let container = try HealthSnapshotMirrorContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)
        let record = HealthSnapshotMirrorRecord(
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            syncedAt: Date(timeIntervalSince1970: 1_700_000_100),
            sourceDevice: "visionOS",
            payloadVersion: 1,
            payloadJSON: "{\"score\":80}"
        )

        context.insert(record)
        try context.save()

        let results = try context.fetch(
            FetchDescriptor<HealthSnapshotMirrorRecord>(
                sortBy: [SortDescriptor(\HealthSnapshotMirrorRecord.fetchedAt, order: .reverse)]
            )
        )

        #expect(results.count == 1)
        #expect(results.first?.sourceDevice == "visionOS")
        #expect(results.first?.payloadJSON == "{\"score\":80}")
    }

    @Test("Only a public library identifier can become a Quick Start iCloud key")
    @MainActor
    func preferenceKeysExcludeWorkoutAndCustomIDs() throws {
        let definition = try #require(ExerciseLibraryService.shared.allExercises().first)
        let key = try #require(QuickStartFavoriteSync.preferenceKey(for: definition.id))
        #expect(QuickStartFavoriteSync.isPreferenceKey(key))
        #expect(QuickStartFavoriteSync.preferenceKey(for: UUID().uuidString) == nil)
        #expect(QuickStartFavoriteSync.preferenceKey(for: "custom-private-user-input") == nil)
    }

    @Test("Restoring a Quick Start favorite twice preserves other fields and the stable catalog identity")
    @MainActor
    func restoringFavoritesIsIdempotent() throws {
        let schema = Schema([ExerciseDefaultRecord.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        ))
        let context = container.mainContext
        let record = ExerciseDefaultRecord(exerciseDefinitionID: "lat-pulldown", defaultWeight: 40, defaultReps: 8)
        let lastUsed = record.lastUsedDate
        context.insert(record)
        try context.save()
        let prefs = [("lat-pulldown", true), ("seated-cable-row", true), ("unstarred", false)]
        #expect(QuickStartFavoriteSync.apply(prefs, to: [record], in: context))
        try context.save()
        let all = try context.fetch(FetchDescriptor<ExerciseDefaultRecord>())
        #expect(all.count == 2)
        #expect(!QuickStartFavoriteSync.apply(prefs, to: all, in: context))
        #expect(record.isPreferred)
        #expect(record.defaultWeight == 40)
        #expect(record.defaultReps == 8)
        #expect(record.lastUsedDate == lastUsed)
        #expect(all.first(where: { $0.exerciseDefinitionID == "seated-cable-row" })?.lastUsedDate == .distantPast)
        #expect(QuickStartFavoriteSync.apply([("lat-pulldown", false)], to: all, in: context))
        #expect(!record.isPreferred)
        #expect(record.defaultWeight == 40)
    }

    @Test("Backup exclusion covers the health store and its sidecars without affecting neighboring files")
    func excludesOnlyHealthStoreFamilyFromBackup() throws {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }
        let store = directory.appendingPathComponent("default.store")
        let wal = directory.appendingPathComponent("default.store-wal")
        let assets = directory.appendingPathComponent("default_ckAssets", isDirectory: true)
        let unrelated = directory.appendingPathComponent("user-preferences.json")
        for file in [store, wal, unrelated] { try Data().write(to: file) }
        try fm.createDirectory(at: assets, withIntermediateDirectories: true)
        try HealthStoreBackupPolicy.excludeStoreFamily(at: store)
        for member in [store, wal, assets] {
            #expect(try member.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        }
        for member in [directory, unrelated] {
            #expect(try member.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup != true)
        }
    }

    @Test("A fresh device restores only allowed routine fields and preserves each local private override")
    @MainActor
    func routinePlanBackupRoundTrip() throws {
        let schema = Schema([WorkoutTemplate.self])
        func makeContainer() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        }
        let source = try makeContainer()
        let fresh = try makeContainer()
        let a = source.mainContext
        let b = fresh.mainContext
        let suiteA = "routine-tests-" + UUID().uuidString
        let suiteB = "routine-tests-" + UUID().uuidString
        let defaultsA = try #require(UserDefaults(suiteName: suiteA))
        let defaultsB = try #require(UserDefaults(suiteName: suiteB))
        defer { defaultsA.removePersistentDomain(forName: suiteA); defaultsB.removePersistentDomain(forName: suiteB) }
        let writerA = UUID().uuidString
        let writerB = UUID().uuidString
        let catalog = try #require(ExerciseLibraryService.shared.allExercises().first)
        let row = TemplateEntry(exerciseDefinitionID: catalog.id, exerciseName: "private entry label", defaultSets: 4, defaultReps: 9, defaultWeightKg: 37, restDuration: 113)
        let routine = WorkoutTemplate(name: "private routine label", exerciseEntries: [row])
        a.insert(routine)
        a.insert(WorkoutTemplate(name: "private custom label", exerciseEntries: [
            TemplateEntry(exerciseDefinitionID: "custom-" + UUID().uuidString, exerciseName: "private custom exercise")
        ]))
        try a.save()
        let cloud = MemoryRoutinePlanCloud()
        #expect(try ExerciseLibraryBackup.reconcile(in: a, cloud: cloud, writer: writerA, defaults: defaultsA))
        let bytes = try #require(cloud.dictionaryRepresentation.values.first as? Data)
        let text = try #require(String(data: bytes, encoding: .utf8))
        #expect(cloud.dictionaryRepresentation.count == 1)
        #expect(!text.contains("private"))
        let json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let plan = try #require(json["plan"] as? [String: Any])
        #expect(Set(plan.keys) == ["id", "entries"])
        let entries = try #require(plan["entries"] as? [[String: Any]])
        #expect(Set(try #require(entries.first).keys) == ["id", "catalogID", "plannedSets", "plannedReps"])

        #expect(try ExerciseLibraryBackup.reconcile(in: b, cloud: cloud, writer: writerB, defaults: defaultsB))
        #expect(try ExerciseLibraryBackup.reconcile(in: b, cloud: cloud, writer: writerB, defaults: defaultsB))
        let restored = try b.fetch(FetchDescriptor<WorkoutTemplate>())
        #expect(restored.count == 1)
        #expect(cloud.dictionaryRepresentation.count == 1)
        let copy = try #require(restored.first)
        #expect(copy.id == routine.id)
        #expect(copy.name == catalog.localizedName)
        let copiedRow = try #require(copy.exerciseEntries.first)
        #expect(copiedRow.id == row.id)
        #expect(copiedRow.defaultSets == 4 && copiedRow.defaultReps == 9)
        #expect(copiedRow.defaultWeightKg == nil && copiedRow.restDuration == nil)

        copy.exerciseEntries[0].defaultReps = 8
        #expect(try ExerciseLibraryBackup.reconcile(in: b, cloud: cloud, writer: writerB, defaults: defaultsB))
        #expect(try ExerciseLibraryBackup.reconcile(in: a, cloud: cloud, writer: writerA, defaults: defaultsA))
        #expect(routine.exerciseEntries[0].defaultReps == 8)
        #expect(routine.exerciseEntries[0].defaultWeightKg == 37 && routine.exerciseEntries[0].restDuration == 113)
        #expect(routine.name == "private routine label" && routine.exerciseEntries[0].exerciseName == "private entry label")
        #expect(!RoutinePlanProjection.canApply(nil, over: routine))
    }

    @Test("Concurrent offline routine revisions and a missing iCloud cache preserve each device's existing content")
    @MainActor
    func concurrentRoutineChanges() throws {
        let a = UUID().uuidString
        let b = UUID().uuidString
        let common = RoutinePlanRevision(version: 1, clock: [a: 1], plan: nil)
        let changedA = RoutinePlanRevision(version: 1, clock: [a: 2], plan: nil)
        let changedB = RoutinePlanRevision(version: 1, clock: [a: 1, b: 1], plan: nil)
        #expect(RoutinePlanRevision.heads([common, changedA, changedB]) == [changedA, changedB])
        #expect(ExerciseLibraryBackup.action(local: "local", baseline: "original", remote: "remote", deleted: false) == .conflict)
        #expect(ExerciseLibraryBackup.action(local: "local", baseline: "original", remote: nil, deleted: false) == .wait)
        #expect(ExerciseLibraryBackup.action(local: nil, baseline: "original", remote: "original", deleted: false) == .restore)
        #expect(ExerciseLibraryBackup.action(local: nil, baseline: "original", remote: "original", deleted: true) == .upload)
    }

    private func isCloudKitDisabled(_ database: ModelConfiguration.CloudKitDatabase) -> Bool {
        Mirror(reflecting: database).children.contains { child in
            child.label == "_none" && (child.value as? Bool) == true
        }
    }
}


private final class MemoryRoutinePlanCloud: RoutinePlanCloudStore {
    var dictionaryRepresentation: [String: Any] = [:]
    func set(_ object: Any?, forKey key: String) { dictionaryRepresentation[key] = object }
    func synchronize() -> Bool { true }
}
