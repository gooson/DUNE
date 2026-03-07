import SwiftUI
import SwiftData
import HealthKit

@main
struct DUNEVisionApp: App {
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @State private var immersionStyle: ImmersionStyle = .progressive

    private let sharedHealthDataService: SharedHealthDataService
    private let refreshCoordinator: AppRefreshCoordinating
    private let observerManager: HealthKitObserverManager?
    private let workoutService: WorkoutQuerying?

    private static func makeInMemoryFallbackContainer() -> ModelContainer {
        do {
            AppLogger.data.error("visionOS: Falling back to in-memory ModelContainer")
            return try HealthSnapshotMirrorContainerFactory.makeInMemoryContainer()
        } catch {
            fatalError("Failed to create fallback in-memory ModelContainer: \(error)")
        }
    }

    private static func recoverModelContainer(
        after error: Error,
        cloudSyncEnabled: Bool
    ) -> ModelContainer {
        guard PersistentStoreRecovery.shouldDeleteStore(after: error) else {
            AppLogger.data.error("visionOS: Skipping store deletion for non-migration error")
            return makeInMemoryFallbackContainer()
        }

        AppLogger.data.error("visionOS: Deleting persistent store after migration failure")
        HealthSnapshotMirrorContainerFactory.deleteStoreFiles()

        do {
            return try HealthSnapshotMirrorContainerFactory.makeContainer(
                cloudSyncEnabled: cloudSyncEnabled
            )
        } catch {
            AppLogger.data.error("visionOS: ModelContainer retry failed: \(error)")
            return makeInMemoryFallbackContainer()
        }
    }

    private static func makeMirroredSnapshotService(
        cloudSyncEnabled: Bool
    ) -> SharedHealthDataService {
        let modelContainer: ModelContainer
        do {
            modelContainer = try HealthSnapshotMirrorContainerFactory.makeContainer(
                cloudSyncEnabled: cloudSyncEnabled
            )
        } catch {
            AppLogger.data.error("visionOS ModelContainer failed: \(error)")
            modelContainer = recoverModelContainer(
                after: error,
                cloudSyncEnabled: cloudSyncEnabled
            )
        }

        return CloudMirroredSharedHealthDataService(modelContainer: modelContainer)
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
        let healthKitAvailable = HKHealthStore.isHealthDataAvailable()
        let sharedService: SharedHealthDataService
        if healthKitAvailable {
            sharedService = SharedHealthDataServiceImpl(healthKitManager: .shared)
        } else if cloudSyncEnabled {
            AppLogger.healthKit.info("HealthKit unavailable on visionOS. Using CloudKit-mirrored snapshot service.")
            sharedService = Self.makeMirroredSnapshotService(
                cloudSyncEnabled: cloudSyncEnabled
            )
        } else {
            AppLogger.healthKit.info("HealthKit unavailable on visionOS and cloud sync is disabled. Using empty snapshot service.")
            sharedService = VisionUnavailableSharedHealthDataService()
        }
        self.sharedHealthDataService = sharedService
        self.workoutService = healthKitAvailable
            ? WorkoutQueryService(manager: .shared)
            : nil

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

    var body: some Scene {
        WindowGroup {
            VisionContentView(
                sharedHealthDataService: sharedHealthDataService,
                refreshCoordinator: refreshCoordinator,
                workoutService: workoutService
            )
            .tint(.accentColor)
        }

        WindowGroup(id: VisionDashboardWindowKind.condition.windowID) {
            VisionDashboardWindowScene(
                kind: .condition,
                sharedHealthDataService: sharedHealthDataService
            )
            .tint(.accentColor)
        }
        .defaultSize(width: 760, height: 560)

        WindowGroup(id: VisionDashboardWindowKind.activity.windowID) {
            VisionDashboardWindowScene(
                kind: .activity,
                sharedHealthDataService: sharedHealthDataService
            )
            .tint(.accentColor)
        }
        .defaultSize(width: 860, height: 620)

        WindowGroup(id: VisionDashboardWindowKind.sleep.windowID) {
            VisionDashboardWindowScene(
                kind: .sleep,
                sharedHealthDataService: sharedHealthDataService
            )
            .tint(.accentColor)
        }
        .defaultSize(width: 760, height: 560)

        WindowGroup(id: VisionDashboardWindowKind.body.windowID) {
            VisionDashboardWindowScene(
                kind: .body,
                sharedHealthDataService: sharedHealthDataService
            )
            .tint(.accentColor)
        }
        .defaultSize(width: 760, height: 560)

        // 3D Charts window — opened via openWindow(id:)
        WindowGroup(id: "chart3d") {
            Chart3DContainerView(sharedHealthDataService: sharedHealthDataService, workoutService: workoutService)
                .tint(.accentColor)
        }
        .defaultSize(width: 800, height: 600, depth: 400)

        WindowGroup(id: "spatial-volume") {
            VisionVolumetricExperienceView(sharedHealthDataService: sharedHealthDataService)
                .tint(.accentColor)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.4, height: 0.95, depth: 0.85, in: .meters)

        ImmersiveSpace(id: "immersive-recovery") {
            VisionImmersiveExperienceView(sharedHealthDataService: sharedHealthDataService)
                .tint(.accentColor)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed, .progressive, .full)
    }
}

private actor VisionUnavailableSharedHealthDataService: SharedHealthDataService {
    func fetchSnapshot() async -> SharedHealthSnapshot {
        SharedHealthSnapshot(
            hrvSamples: [],
            todayRHR: nil,
            yesterdayRHR: nil,
            latestRHR: nil,
            rhrCollection: [],
            todaySleepStages: [],
            yesterdaySleepStages: [],
            latestSleepStages: nil,
            sleepDailyDurations: [],
            conditionScore: nil,
            baselineStatus: nil,
            recentConditionScores: [],
            failedSources: [],
            fetchedAt: Date()
        )
    }

    func invalidateCache() async {}
}
