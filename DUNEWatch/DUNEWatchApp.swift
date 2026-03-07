import SwiftUI
import SwiftData
import OSLog

@main
struct DUNEWatchApp: App {
    @State private var connectivity = WatchConnectivityManager.shared
    private static let logger = Logger(subsystem: "com.raftel.dailve", category: "WatchApp")

    let modelContainer: ModelContainer

    private static func makeModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: AppMigrationPlan.currentSchema,
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
    }

    private static func makeInMemoryFallbackContainer() -> ModelContainer {
        let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            logger.error("Falling back to in-memory ModelContainer due to persistent store failure")
            return try makeModelContainer(configuration: fallbackConfiguration)
        } catch {
            fatalError("Failed to create fallback in-memory ModelContainer: \(error)")
        }
    }

    private static var shouldEnableCloudKit: Bool {
#if targetEnvironment(simulator)
        logger.info("CloudKit disabled on watch simulator")
        return false
#else
        // Watch has no user-facing cloud sync toggle yet, so gate by account availability.
        let hasICloudAccount = FileManager.default.ubiquityIdentityToken != nil
        if !hasICloudAccount {
            logger.info("CloudKit disabled on watch app due to missing iCloud account")
        }
        return hasICloudAccount
#endif
    }

    init() {
        let config = ModelConfiguration(
            cloudKitDatabase: Self.shouldEnableCloudKit ? .automatic : .none
        )
        do {
            modelContainer = try Self.makeModelContainer(configuration: config)
        } catch {
            Self.logger.error("ModelContainer failed: \(error.localizedDescription, privacy: .public)")
            modelContainer = Self.recoverModelContainer(after: error, configuration: config)
        }
    }

    private static func deleteStoreFiles(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: url.path + suffix)
            try? fm.removeItem(at: fileURL)
        }
    }

    private static func recoverModelContainer(after error: Error, configuration: ModelConfiguration) -> ModelContainer {
        guard PersistentStoreRecovery.shouldDeleteStore(after: error) else {
            logger.error("Skipping store deletion for non-migration container error")
            return makeInMemoryFallbackContainer()
        }

        logger.error("Deleting persistent store after migration compatibility failure")
        deleteStoreFiles(at: configuration.url)

        do {
            return try makeModelContainer(configuration: configuration)
        } catch {
            logger.error("ModelContainer retry failed: \(error.localizedDescription, privacy: .public)")
            return makeInMemoryFallbackContainer()
        }
    }

    /// Theme synced from iPhone via WatchConnectivity.
    /// Falls back to desertWarm if never synced.
    private var resolvedTheme: AppTheme {
        AppTheme.resolvedTheme(fromPersistedRawValue: connectivity.syncedThemeRawValue) ?? .desertWarm
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectivity)
                .environment(\.appTheme, resolvedTheme)
                .tint(resolvedTheme.accentColor)
                .onAppear {
                    connectivity.activate()
                }
        }
        .modelContainer(modelContainer)
    }
}
