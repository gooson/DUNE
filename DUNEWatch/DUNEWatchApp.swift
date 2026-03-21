import SwiftUI
import SwiftData
import OSLog

@main
struct DUNEWatchApp: App {
    @State private var connectivity = WatchConnectivityManager.shared
    @State private var postureMonitor = WatchPostureMonitor.shared
    private static let logger = Logger(subsystem: "com.raftel.dailve", category: "WatchApp")

    let modelContainer: ModelContainer

    private static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting-watch")
    }

    private struct UITestLaunchConfiguration {
        let shouldResetState: Bool

        static func current(isRunningUITests: Bool) -> Self {
            guard isRunningUITests else {
                return Self(shouldResetState: false)
            }

            return Self(
                shouldResetState: ProcessInfo.processInfo.arguments.contains("--ui-reset")
            )
        }
    }

    private static let uiTestLaunchConfiguration = UITestLaunchConfiguration.current(
        isRunningUITests: isRunningUITests
    )

    private static func makeModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        // All migration stages are .lightweight — automatic migration handles them.
        // Staged plan removed due to drifted VersionedSchema hashes causing 134504.
        try ModelContainer(
            for: AppMigrationPlan.currentSchema,
            configurations: configuration
        )
    }

    private static func makeInMemoryFallbackContainer() -> ModelContainer {
        logger.error("Falling back to in-memory ModelContainer due to persistent store failure")
        let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            // Skip migration plan — in-memory stores have nothing to migrate.
            return try makeFreshModelContainer(configuration: fallbackConfiguration)
        } catch {
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: Schema([]), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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
            isStoredInMemoryOnly: Self.uiTestLaunchConfiguration.shouldResetState,
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
            do {
                try fm.removeItem(at: fileURL)
                logger.info("Deleted store file: \(fileURL.lastPathComponent)")
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                // File doesn't exist — nothing to delete.
            } catch {
                logger.error("Failed to delete store file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    /// Create a ModelContainer WITHOUT the migration plan — for fresh stores after deletion.
    private static func makeFreshModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: AppMigrationPlan.currentSchema,
            configurations: configuration
        )
    }

    private static func recoverModelContainer(after error: Error, configuration: ModelConfiguration) -> ModelContainer {
        let reflectedError = String(reflecting: error)
        guard PersistentStoreRecovery.shouldDeleteStore(after: error) else {
            logger.error("Skipping store deletion for non-migration container error: \(reflectedError, privacy: .private)")
            return makeInMemoryFallbackContainer()
        }

        logger.error("Deleting persistent store after migration compatibility failure: \(reflectedError, privacy: .private)")
        deleteStoreFiles(at: configuration.url)

        // Retry 1: fresh container WITHOUT migration plan (deleted store needs no migration).
        do {
            let container = try makeFreshModelContainer(configuration: configuration)
            logger.info("ModelContainer recovered with fresh store (no migration plan).")
            return container
        } catch {
            logger.error("Fresh ModelContainer retry failed: \(error.localizedDescription, privacy: .public)")
        }

        // Retry 2: fresh container without CloudKit either.
        do {
            let noCloudConfig = ModelConfiguration(
                url: configuration.url,
                cloudKitDatabase: .none
            )
            let container = try makeFreshModelContainer(configuration: noCloudConfig)
            logger.info("ModelContainer recovered without CloudKit.")
            return container
        } catch {
            logger.error("Fresh ModelContainer retry without CloudKit also failed: \(error.localizedDescription, privacy: .public)")
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
                    postureMonitor.startMonitoringIfEnabled()
                }
        }
        .modelContainer(modelContainer)
    }
}
