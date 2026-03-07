import Foundation
import SwiftData

enum HealthSnapshotMirrorContainerFactory {
    static let storeName = "HealthSnapshotMirror"
    static let storeFilename = "health-snapshot-mirror.store"
    static let schema = Schema([HealthSnapshotMirrorRecord.self])

    static func configuration(
        cloudSyncEnabled: Bool,
        url: URL? = nil
    ) -> ModelConfiguration {
        ModelConfiguration(
            storeName,
            schema: schema,
            url: url ?? defaultStoreURL(),
            cloudKitDatabase: cloudSyncEnabled ? .automatic : .none
        )
    }

    static func makeContainer(
        cloudSyncEnabled: Bool,
        url: URL? = nil
    ) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: configuration(cloudSyncEnabled: cloudSyncEnabled, url: url)
        )
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            storeName,
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func deleteStoreFiles(at url: URL? = nil) {
        let storeURL = url ?? defaultStoreURL()
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: storeURL.path + suffix)
            try? fileManager.removeItem(at: fileURL)
        }
    }

    static func defaultStoreURL() -> URL {
        let fileManager = FileManager.default
        let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let directory = applicationSupportDirectory.appendingPathComponent("DUNE", isDirectory: true)
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return directory.appendingPathComponent(storeFilename, isDirectory: false)
    }
}
