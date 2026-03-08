import Foundation
import SwiftData

enum CloudSyncPreferenceStore {
    static let storageKey = "isCloudSyncEnabled"

    enum RuntimeRefreshAction: Equatable {
        case noChange(resolvedValue: Bool)
        case rebuild(resolvedValue: Bool)
    }

    @discardableResult
    static func resolvedValue(
        userDefaults: UserDefaults = .standard,
        ubiquitousStore: NSUbiquitousKeyValueStore = .default
    ) -> Bool {
        ubiquitousStore.synchronize()

        let localValue = booleanValue(from: userDefaults.object(forKey: storageKey))
        let cloudValue = booleanValue(from: ubiquitousStore.object(forKey: storageKey))
        let resolution = makeResolution(localValue: localValue, cloudValue: cloudValue)
        let resolved = resolution.resolvedValue

        if localValue != resolved {
            userDefaults.set(resolved, forKey: storageKey)
        }

        if let seedValue = resolution.seedValue {
            ubiquitousStore.set(seedValue, forKey: storageKey)
            ubiquitousStore.synchronize()
        }

        return resolved
    }

    static func setEnabled(
        _ isEnabled: Bool,
        userDefaults: UserDefaults = .standard,
        ubiquitousStore: NSUbiquitousKeyValueStore = .default
    ) {
        userDefaults.set(isEnabled, forKey: storageKey)
        ubiquitousStore.set(isEnabled, forKey: storageKey)
        ubiquitousStore.synchronize()
    }

    static func resolve(localValue: Bool?, cloudValue: Bool?) -> Bool {
        cloudValue ?? localValue ?? false
    }

    static func cloudSeedValue(localValue: Bool?, cloudValue: Bool?) -> Bool? {
        guard cloudValue == nil else { return nil }
        guard localValue == true else { return nil }
        return true
    }

    static func runtimeRefreshAction(
        currentValue: Bool,
        localValue: Bool?,
        cloudValue: Bool?
    ) -> RuntimeRefreshAction {
        runtimeRefreshAction(
            currentValue: currentValue,
            resolvedValue: makeResolution(localValue: localValue, cloudValue: cloudValue).resolvedValue
        )
    }

    static func runtimeRefreshAction(
        currentValue: Bool,
        resolvedValue: Bool
    ) -> RuntimeRefreshAction {
        if currentValue == resolvedValue {
            return .noChange(resolvedValue: resolvedValue)
        }
        return .rebuild(resolvedValue: resolvedValue)
    }

    private static func makeResolution(localValue: Bool?, cloudValue: Bool?) -> Resolution {
        Resolution(
            resolvedValue: resolve(localValue: localValue, cloudValue: cloudValue),
            seedValue: cloudSeedValue(localValue: localValue, cloudValue: cloudValue)
        )
    }

    private static func booleanValue(from object: Any?) -> Bool? {
        if let boolValue = object as? Bool {
            return boolValue
        }
        if let numberValue = object as? NSNumber {
            return numberValue.boolValue
        }
        return nil
    }

    private struct Resolution {
        let resolvedValue: Bool
        let seedValue: Bool?
    }
}

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
