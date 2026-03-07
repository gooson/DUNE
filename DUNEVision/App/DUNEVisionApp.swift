import SwiftUI
import HealthKit

@main
struct DUNEVisionApp: App {
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @State private var immersionStyle: ImmersionStyle = .progressive

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

        let healthKitAvailable = HKHealthStore.isHealthDataAvailable()
        let sharedService: SharedHealthDataService
        if healthKitAvailable {
            sharedService = SharedHealthDataServiceImpl(healthKitManager: .shared)
        } else {
            AppLogger.healthKit.info("HealthKit unavailable on visionOS. Using empty snapshot service.")
            sharedService = VisionUnavailableSharedHealthDataService()
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

    var body: some Scene {
        WindowGroup {
            VisionContentView(
                sharedHealthDataService: sharedHealthDataService,
                refreshCoordinator: refreshCoordinator
            )
            .tint(.accentColor)
        }

        // 3D Charts window — opened via openWindow(id:)
        WindowGroup(id: "chart3d") {
            Chart3DContainerView(sharedHealthDataService: sharedHealthDataService)
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
