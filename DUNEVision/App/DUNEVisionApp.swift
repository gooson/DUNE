import SwiftUI
import SwiftData
import HealthKit

@main
struct DUNEVisionApp: App {
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @State private var immersionStyle: ImmersionStyle = .progressive

    private let modelContainer: ModelContainer
    private let sharedHealthDataService: SharedHealthDataService
    private let refreshCoordinator: AppRefreshCoordinating
    private let observerManager: HealthKitObserverManager?
    private var workoutService: WorkoutQuerying
    private let historyModelContainer: ModelContainer

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

    private static func makeMirroredSnapshotContainer(
        cloudSyncEnabled: Bool
    ) -> ModelContainer {
        do {
            return try HealthSnapshotMirrorContainerFactory.makeContainer(
                cloudSyncEnabled: cloudSyncEnabled
            )
        } catch {
            AppLogger.data.error("visionOS ModelContainer failed: \(error)")
            return recoverModelContainer(
                after: error,
                cloudSyncEnabled: cloudSyncEnabled
            )
        }
    }

    private static func makeExerciseHistoryFallbackContainer() -> ModelContainer {
        do {
            AppLogger.data.error("visionOS: Falling back to in-memory exercise history container")
            return try VisionExerciseHistoryContainerFactory.makeInMemoryContainer()
        } catch {
            fatalError("Failed to create fallback exercise history container: \(error)")
        }
    }

    private static func recoverExerciseHistoryModelContainer(
        after error: Error,
        cloudSyncEnabled: Bool
    ) -> ModelContainer {
        guard PersistentStoreRecovery.shouldDeleteStore(after: error) else {
            AppLogger.data.error("visionOS: Skipping exercise history store deletion for non-migration error")
            return makeExerciseHistoryFallbackContainer()
        }

        AppLogger.data.error("visionOS: Deleting exercise history store after migration failure")
        VisionExerciseHistoryContainerFactory.deleteStoreFiles()

        do {
            return try VisionExerciseHistoryContainerFactory.makeContainer(
                cloudSyncEnabled: cloudSyncEnabled
            )
        } catch {
            AppLogger.data.error("visionOS: Exercise history container retry failed: \(error)")
            return makeExerciseHistoryFallbackContainer()
        }
    }

    private static func makeExerciseHistoryModelContainer(
        cloudSyncEnabled: Bool
    ) -> ModelContainer {
        do {
            return try VisionExerciseHistoryContainerFactory.makeContainer(
                cloudSyncEnabled: cloudSyncEnabled
            )
        } catch {
            AppLogger.data.error("visionOS exercise history ModelContainer failed: \(error)")
            return recoverExerciseHistoryModelContainer(
                after: error,
                cloudSyncEnabled: cloudSyncEnabled
            )
        }
    }

    private func makeWindowPlacement(
        for windowID: String,
        context: WindowPlacementContext
    ) -> WindowPlacement {
        let relationship = VisionWindowPlacementPlanner.relationship(
            for: windowID,
            existingWindowIDs: Set(context.windows.map(\.id))
        )

        switch relationship {
        case .utilityPanel:
            return WindowPlacement(.utilityPanel)

        case let .leading(relativeID):
            guard let relativeWindow = windowProxy(id: relativeID, in: context) else {
                return WindowPlacement(.utilityPanel)
            }
            return WindowPlacement(.leading(relativeWindow))

        case let .trailing(relativeID):
            guard let relativeWindow = windowProxy(id: relativeID, in: context) else {
                return WindowPlacement(.utilityPanel)
            }
            return WindowPlacement(.trailing(relativeWindow))

        case let .above(relativeID):
            guard let relativeWindow = windowProxy(id: relativeID, in: context) else {
                return WindowPlacement(.utilityPanel)
            }
            return WindowPlacement(.above(relativeWindow))

        case let .below(relativeID):
            guard let relativeWindow = windowProxy(id: relativeID, in: context) else {
                return WindowPlacement(.utilityPanel)
            }
            return WindowPlacement(.below(relativeWindow))
        }
    }

    private func windowProxy(
        id: String?,
        in context: WindowPlacementContext
    ) -> WindowProxy? {
        context.windows.first { $0.id == id }
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
        let mirroredContainer = Self.makeMirroredSnapshotContainer(
            cloudSyncEnabled: cloudSyncEnabled
        )
        self.modelContainer = mirroredContainer

        let sharedService: SharedHealthDataService
        if healthKitAvailable {
            sharedService = SharedHealthDataServiceImpl(healthKitManager: .shared)
        } else {
            AppLogger.healthKit.info("HealthKit unavailable on visionOS. Using mirrored snapshot service.")
            sharedService = CloudMirroredSharedHealthDataService(modelContainer: mirroredContainer)
        }
        self.sharedHealthDataService = sharedService
        self.workoutService = WorkoutQueryService(manager: .shared)
        self.historyModelContainer = Self.makeExerciseHistoryModelContainer(
            cloudSyncEnabled: cloudSyncEnabled
        )
        self.workoutService = WorkoutQueryService(manager: .shared)

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
                modelContainer: modelContainer,
                sharedHealthDataService: sharedHealthDataService,
                refreshCoordinator: refreshCoordinator,
                workoutService: workoutService
            )
            .tint(.accentColor)
            .modelContainer(historyModelContainer)
        }

        WindowGroup(id: VisionDashboardWindowKind.condition.windowID) {
            VisionDashboardWindowScene(
                kind: .condition,
                sharedHealthDataService: sharedHealthDataService,
                workoutService: workoutService
            )
            .tint(.accentColor)
        }
        .defaultSize(width: 760, height: 560)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionDashboardWindowKind.condition.windowID, context: context)
        }

        WindowGroup(id: VisionDashboardWindowKind.activity.windowID) {
            VisionDashboardWindowScene(
                kind: .activity,
                sharedHealthDataService: sharedHealthDataService,
                workoutService: workoutService
            )
            .tint(.accentColor)
        }
        .defaultSize(width: 860, height: 620)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionDashboardWindowKind.activity.windowID, context: context)
        }

        WindowGroup(id: VisionDashboardWindowKind.sleep.windowID) {
            VisionDashboardWindowScene(
                kind: .sleep,
                sharedHealthDataService: sharedHealthDataService,
                workoutService: workoutService
            )
            .tint(.accentColor)
        }
        .defaultSize(width: 760, height: 560)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionDashboardWindowKind.sleep.windowID, context: context)
        }

        WindowGroup(id: VisionDashboardWindowKind.body.windowID) {
            VisionDashboardWindowScene(
                kind: .body,
                sharedHealthDataService: sharedHealthDataService,
                workoutService: workoutService
            )
            .tint(.accentColor)
        }
        .defaultSize(width: 760, height: 560)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionDashboardWindowKind.body.windowID, context: context)
        }

        // 3D Charts window — opened via openWindow(id:)
        WindowGroup(id: "chart3d") {
            Chart3DContainerView(sharedHealthDataService: sharedHealthDataService, workoutService: workoutService)
                .tint(.accentColor)
        }
        .defaultSize(width: 800, height: 600, depth: 400)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionWindowPlacementPlanner.chart3DWindowID, context: context)
        }

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
