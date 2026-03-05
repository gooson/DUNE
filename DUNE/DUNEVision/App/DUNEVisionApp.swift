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
            modelContainer = try ModelContainer(
                for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self,
                CustomExercise.self, WorkoutTemplate.self, UserCategory.self,
                InjuryRecord.self, ExerciseDefaultRecord.self,
                HabitDefinition.self, HabitLog.self, HealthSnapshotMirrorRecord.self,
                migrationPlan: AppMigrationPlan.self,
                configurations: config
            )
        } catch {
            AppLogger.data.error("ModelContainer failed: \(error)")
            Self.deleteStoreFiles(at: config.url)
            do {
                modelContainer = try ModelContainer(
                    for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self,
                    CustomExercise.self, WorkoutTemplate.self, UserCategory.self,
                    InjuryRecord.self, ExerciseDefaultRecord.self,
                    HabitDefinition.self, HabitLog.self, HealthSnapshotMirrorRecord.self,
                    migrationPlan: AppMigrationPlan.self,
                    configurations: config
                )
            } catch {
                AppLogger.data.error("ModelContainer retry failed: \(error)")
                let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                do {
                    modelContainer = try ModelContainer(
                        for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self,
                        CustomExercise.self, WorkoutTemplate.self, UserCategory.self,
                        InjuryRecord.self, ExerciseDefaultRecord.self,
                        HabitDefinition.self, HabitLog.self, HealthSnapshotMirrorRecord.self,
                        migrationPlan: AppMigrationPlan.self,
                        configurations: fallbackConfig
                    )
                } catch {
                    fatalError("Failed to create fallback in-memory ModelContainer: \(error)")
                }
            }
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
