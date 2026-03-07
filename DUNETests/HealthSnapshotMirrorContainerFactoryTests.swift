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

    @Test("seeds cloud state from local opt-in only when cloud state is missing")
    func seedsCloudStateOnlyWhenMissing() {
        let missingCloudSeed = CloudSyncPreferenceStore.cloudSeedValue(localValue: false, cloudValue: nil)
        let existingCloudSeed = CloudSyncPreferenceStore.cloudSeedValue(localValue: true, cloudValue: false)

        #expect(missingCloudSeed == false)
        #expect(existingCloudSeed == nil)
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
