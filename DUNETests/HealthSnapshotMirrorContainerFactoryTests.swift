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

    @Test("disables CloudKit when sync is off")
    func disablesCloudKitWhenSyncIsOff() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")

        let configuration = HealthSnapshotMirrorContainerFactory.configuration(
            cloudSyncEnabled: false,
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

    private func isCloudKitDisabled(_ database: ModelConfiguration.CloudKitDatabase) -> Bool {
        Mirror(reflecting: database).children.contains { child in
            child.label == "_none" && (child.value as? Bool) == true
        }
    }
}
