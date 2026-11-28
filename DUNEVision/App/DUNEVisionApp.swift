import SwiftUI
import SwiftData
import HealthKit

@main
struct DUNEVisionApp: App {
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @Environment(\.scenePhase) private var scenePhase
    @State private var immersionStyle: ImmersionStyle = .progressive

    private struct Runtime {
        let modelContainer: ModelContainer
        let historyModelContainer: ModelContainer
        let sharedHealthDataService: any SharedHealthDataService
        let refreshCoordinator: any AppRefreshCoordinating
        let observerManager: HealthKitObserverManager?
        let workoutService: any WorkoutQuerying
    }

    @State private var storeOpening: PersistentStoreOpening<Runtime>

    private static func openRuntime() -> PersistentStoreOpening<Runtime> {
        PersistentStoreOpening {
            let mirror = try HealthSnapshotMirrorContainerFactory.makeContainer()
            let history = try VisionExerciseHistoryContainerFactory.makeContainer()
            let healthAvailable = HKHealthStore.isHealthDataAvailable()
            let service: any SharedHealthDataService
            if healthAvailable {
                service = SharedHealthDataServiceImpl(healthKitManager: .shared)
            } else {
                service = CloudMirroredSharedHealthDataService(modelContainer: mirror)
            }
            let coordinator = AppRefreshCoordinatorImpl(sharedHealthDataService: service)
            let observer = healthAvailable ? HealthKitObserverManager(
                store: HKHealthStore(), coordinator: coordinator, notificationEvaluator: nil
            ) : nil
            return Runtime(modelContainer: mirror, historyModelContainer: history, sharedHealthDataService: service,
                           refreshCoordinator: coordinator, observerManager: observer, workoutService: WorkoutQueryService(manager: .shared))
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

        _storeOpening = State(initialValue: Self.openRuntime())
    }

    @ViewBuilder
    private func loaded<Content: View>(@ViewBuilder _ content: (Runtime) -> Content) -> some View {
        storeOpening.content(retry: { storeOpening = Self.openRuntime() }, ready: content)
    }

    var body: some Scene {
        WindowGroup {
            loaded { runtime in
                VisionContentView(
                    modelContainer: runtime.modelContainer,
                    sharedHealthDataService: runtime.sharedHealthDataService,
                    refreshCoordinator: runtime.refreshCoordinator,
                    workoutService: runtime.workoutService
                )
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background {
                        HealthStoreBackupPolicy.refresh(runtime.modelContainer)
                        HealthStoreBackupPolicy.refresh(runtime.historyModelContainer)
                    }
                }
                .tint(VisionThemePalette.accentColor(for: selectedTheme))
                .modelContainer(runtime.historyModelContainer)
            }
        }

        WindowGroup(id: VisionDashboardWindowKind.condition.windowID) {
            loaded { runtime in
                VisionDashboardWindowScene(
                    kind: .condition,
                    sharedHealthDataService: runtime.sharedHealthDataService,
                    workoutService: runtime.workoutService
                )
                .tint(VisionThemePalette.accentColor(for: selectedTheme))
            }
        }
        .defaultSize(width: 760, height: 560)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionDashboardWindowKind.condition.windowID, context: context)
        }

        WindowGroup(id: VisionDashboardWindowKind.activity.windowID) {
            loaded { runtime in
                VisionDashboardWindowScene(
                    kind: .activity,
                    sharedHealthDataService: runtime.sharedHealthDataService,
                    workoutService: runtime.workoutService
                )
                .tint(VisionThemePalette.accentColor(for: selectedTheme))
            }
        }
        .defaultSize(width: 860, height: 620)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionDashboardWindowKind.activity.windowID, context: context)
        }

        WindowGroup(id: VisionDashboardWindowKind.sleep.windowID) {
            loaded { runtime in
                VisionDashboardWindowScene(
                    kind: .sleep,
                    sharedHealthDataService: runtime.sharedHealthDataService,
                    workoutService: runtime.workoutService
                )
                .tint(VisionThemePalette.accentColor(for: selectedTheme))
            }
        }
        .defaultSize(width: 760, height: 560)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionDashboardWindowKind.sleep.windowID, context: context)
        }

        WindowGroup(id: VisionDashboardWindowKind.body.windowID) {
            loaded { runtime in
                VisionDashboardWindowScene(
                    kind: .body,
                    sharedHealthDataService: runtime.sharedHealthDataService,
                    workoutService: runtime.workoutService
                )
                .tint(VisionThemePalette.accentColor(for: selectedTheme))
            }
        }
        .defaultSize(width: 760, height: 560)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionDashboardWindowKind.body.windowID, context: context)
        }

        WindowGroup(id: VisionWindowPlacementPlanner.settingsWindowID) {
            loaded { runtime in
                NavigationStack {
                    VisionSettingsView(modelContainer: runtime.modelContainer)
                }
                .tint(VisionThemePalette.accentColor(for: selectedTheme))
            }
        }
        .defaultSize(width: 520, height: 620)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionWindowPlacementPlanner.settingsWindowID, context: context)
        }

        // 3D Charts window — opened via openWindow(id:)
        WindowGroup(id: "chart3d") {
            loaded { runtime in
                Chart3DContainerView(sharedHealthDataService: runtime.sharedHealthDataService, workoutService: runtime.workoutService)
                    .tint(VisionThemePalette.accentColor(for: selectedTheme))
            }
        }
        .defaultSize(width: 800, height: 600, depth: 400)
        .defaultWindowPlacement { _, context in
            makeWindowPlacement(for: VisionWindowPlacementPlanner.chart3DWindowID, context: context)
        }

        WindowGroup(id: "spatial-volume") {
            loaded { runtime in
                VisionVolumetricExperienceView(sharedHealthDataService: runtime.sharedHealthDataService)
                    .tint(VisionThemePalette.accentColor(for: selectedTheme))
            }
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.4, height: 0.95, depth: 0.85, in: .meters)

        ImmersiveSpace(id: "immersive-recovery") {
            loaded { runtime in
                VisionImmersiveExperienceView(sharedHealthDataService: runtime.sharedHealthDataService)
                    .tint(VisionThemePalette.accentColor(for: selectedTheme))
            }
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
