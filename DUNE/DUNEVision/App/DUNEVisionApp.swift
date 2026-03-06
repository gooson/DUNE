import SwiftUI
import SwiftData
import HealthKit

@main
struct DUNEVisionApp: App {
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm

    let modelContainer: ModelContainer
    private let sharedHealthDataService: SharedHealthDataService
    private let refreshCoordinator: AppRefreshCoordinating
    private let observerManager: HealthKitObserverManager?

    private static func makeModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self,
            CustomExercise.self, WorkoutTemplate.self, UserCategory.self,
            InjuryRecord.self, ExerciseDefaultRecord.self,
            HabitDefinition.self, HabitLog.self, HealthSnapshotMirrorRecord.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
    }

    init() {
        let persistedThemeRawValue = UserDefaults.standard.string(forKey: AppTheme.storageKey)
        if let normalizedTheme = AppTheme.resolvedTheme(fromPersistedRawValue: persistedThemeRawValue) {
            if persistedThemeRawValue != normalizedTheme.rawValue {
                UserDefaults.standard.set(normalizedTheme.rawValue, forKey: AppTheme.storageKey)
            }
            _selectedTheme = AppStorage(wrappedValue: normalizedTheme, AppTheme.storageKey)
        }

        let cloudSyncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")
        let config = ModelConfiguration(
            cloudKitDatabase: cloudSyncEnabled ? .automatic : .none
        )
        do {
            modelContainer = try Self.makeModelContainer(configuration: config)
        } catch {
            AppLogger.data.error("ModelContainer failed: \(error)")
            modelContainer = Self.recoverModelContainer(after: error, configuration: config)
        }

        let healthKitAvailable = HKHealthStore.isHealthDataAvailable()
        let sharedService: SharedHealthDataService
        if healthKitAvailable {
            let baseSharedService: SharedHealthDataService = SharedHealthDataServiceImpl(healthKitManager: .shared)
            let mirrorStore: HealthSnapshotMirroring = HealthSnapshotMirrorStore(modelContainer: modelContainer)
            sharedService = MirroringSharedHealthDataService(
                baseService: baseSharedService,
                mirrorStore: mirrorStore
            )
        } else {
            AppLogger.healthKit.info("HealthKit unavailable on visionOS. Using cloud mirrored snapshot service.")
            sharedService = CloudMirroredSharedHealthDataService(modelContainer: modelContainer)
        }
        self.sharedHealthDataService = sharedService

        let coordinator = AppRefreshCoordinatorImpl(sharedHealthDataService: sharedService)
        self.refreshCoordinator = coordinator

        if healthKitAvailable {
            let hkStore = HKHealthStore()
            self.observerManager = HealthKitObserverManager(
                store: hkStore,
                coordinator: coordinator,
                notificationEvaluator: nil
            )
        } else {
            self.observerManager = nil
        }
    }

    private static func deleteStoreFiles(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: url.path + suffix)
            try? fm.removeItem(at: fileURL)
        }
    }

    private static func makeInMemoryFallbackContainer() -> ModelContainer {
        let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            AppLogger.data.error("Falling back to in-memory ModelContainer due to persistent store failure")
            return try makeModelContainer(configuration: fallbackConfiguration)
        } catch {
            fatalError("Failed to create fallback in-memory ModelContainer: \(error)")
        }
    }

    private static func recoverModelContainer(after error: Error, configuration: ModelConfiguration) -> ModelContainer {
        guard PersistentStoreRecovery.shouldDeleteStore(after: error) else {
            AppLogger.data.error("Skipping store deletion for non-migration container error")
            return makeInMemoryFallbackContainer()
        }

        AppLogger.data.error("Deleting persistent store after migration compatibility failure")
        deleteStoreFiles(at: configuration.url)

        do {
            return try makeModelContainer(configuration: configuration)
        } catch {
            AppLogger.data.error("ModelContainer retry failed: \(error)")
            return makeInMemoryFallbackContainer()
        }
    }

    var body: some Scene {
        WindowGroup {
            VisionContentView(
                sharedHealthDataService: sharedHealthDataService,
                refreshCoordinator: refreshCoordinator
            )
            .tint(selectedTheme.accentColor)
        }
        .modelContainer(modelContainer)

        // 3D Charts window — opened via openWindow(id:)
        WindowGroup(id: "chart3d") {
            Chart3DContainerView(sharedHealthDataService: sharedHealthDataService)
                .tint(selectedTheme.accentColor)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 800, height: 600, depth: 400)
    }
}
