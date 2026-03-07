import Foundation
import SwiftData
import Testing
@testable import DUNE

@Suite("HealthSnapshotMirrorContainerFactory")
struct HealthSnapshotMirrorContainerFactoryTests {
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
