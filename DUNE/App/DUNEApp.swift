import SwiftUI
import SwiftData
import HealthKit
import UserNotifications

@main
struct DUNEApp: App {
    @AppStorage("com.dune.app.theme") private var selectedTheme: AppTheme = .desertWarm
    @AppStorage("hasShownCloudSyncConsent") private var hasShownConsent = false
    @State private var showConsentSheet = false
    @State private var isShowingLaunchSplash = !DUNEApp.isRunningXCTest
    @State private var isResolvingLaunchSplash = false
    @State private var hasCompletedPostSplashSetup = false
    @State private var hasSeededMockData = false

    let modelContainer: ModelContainer
    private let sharedHealthDataService: SharedHealthDataService
    private let refreshCoordinator: AppRefreshCoordinating
    private let observerManager: HealthKitObserverManager?
    private let notificationService: any NotificationService
    private let notificationCenterDelegate: AppNotificationCenterDelegate
    private static let minimumLaunchSplashDuration: Duration = .seconds(1)
    private static let launchSplashResolveDuration: Duration = .milliseconds(700)

    private static var isRunningXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        || isRunningUITests
    }

    private static var isRunningUITests: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--uitesting") || arguments.contains("--healthkit-permission-uitest")
    }

    private static func launchArgumentValue(for key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    private static var forcedUITestTheme: AppTheme? {
        guard isRunningUITests else { return nil }
        guard let rawValue = launchArgumentValue(for: "--ui-test-theme") else { return nil }
        return AppTheme(rawValue: rawValue)
    }

    private static var forcedUITestColorScheme: ColorScheme? {
        guard isRunningUITests else { return nil }
        guard let style = launchArgumentValue(for: "--ui-test-style")?.lowercased() else { return nil }
        switch style {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    private static var isRunningUnitTests: Bool {
        isRunningXCTest && !isRunningUITests
    }

    private static let shouldSeedMockData: Bool =
        isRunningXCTest && ProcessInfo.processInfo.arguments.contains("--seed-mock")

    private static func makeModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, UserCategory.self, InjuryRecord.self, ExerciseDefaultRecord.self, HabitDefinition.self, HabitLog.self, HealthSnapshotMirrorRecord.self,
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
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

    init() {
        if let forcedTheme = Self.forcedUITestTheme {
            UserDefaults.standard.set(forcedTheme.rawValue, forKey: "com.dune.app.theme")
            _selectedTheme = AppStorage(wrappedValue: forcedTheme, "com.dune.app.theme")
        }
        let cloudSyncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")
        let config = ModelConfiguration(
            cloudKitDatabase: (cloudSyncEnabled && !Self.isRunningXCTest) ? .automatic : .none
        )
        do {
            modelContainer = try Self.makeModelContainer(configuration: config)
        } catch {
            // Schema migration failed — delete store and retry (MVP: no user data to preserve)
            AppLogger.data.error("ModelContainer failed: \(error)")
            Self.deleteStoreFiles(at: config.url)
            do {
                modelContainer = try Self.makeModelContainer(configuration: config)
            } catch {
                AppLogger.data.error("ModelContainer retry failed: \(error)")
                modelContainer = Self.makeInMemoryFallbackContainer()
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
            AppLogger.healthKit.info("HealthKit unavailable. Falling back to cloud mirrored snapshot service.")
            sharedService = CloudMirroredSharedHealthDataService(modelContainer: modelContainer)
        }
        self.sharedHealthDataService = sharedService

        let coordinator = AppRefreshCoordinatorImpl(sharedHealthDataService: sharedService)
        self.refreshCoordinator = coordinator

        let notifService = NotificationServiceImpl()
        self.notificationService = notifService
        self.notificationCenterDelegate = AppNotificationCenterDelegate()
        UNUserNotificationCenter.current().delegate = notificationCenterDelegate

        if healthKitAvailable {
            let hkStore = HKHealthStore()
            let evaluator = BackgroundNotificationEvaluator(
                store: hkStore,
                notificationService: notifService
            )
            self.observerManager = HealthKitObserverManager(
                store: hkStore,
                coordinator: coordinator,
                notificationEvaluator: evaluator
            )
        } else {
            self.observerManager = nil
        }
    }

    private static func deleteStoreFiles(at url: URL) {
        let fm = FileManager.default
        // SwiftData/SQLite uses .sqlite, .sqlite-wal, .sqlite-shm
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: url.path + suffix)
            try? fm.removeItem(at: fileURL)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if Self.isRunningUnitTests {
                    Color.clear
                } else if Self.shouldSeedMockData {
                    // UI test with mock data — seed and skip splash
                    seedableAppContent
                } else {
                    ZStack {
                        if !isShowingLaunchSplash || isResolvingLaunchSplash {
                            appContent
                                .transition(.opacity)
                        }

                        if isShowingLaunchSplash {
                            LaunchSplashView(isResolving: isResolvingLaunchSplash)
                                .allowsHitTesting(!isResolvingLaunchSplash)
                        }
                    }
                    .task(id: isShowingLaunchSplash) {
                        if isShowingLaunchSplash {
                            await dismissLaunchSplashAfterMinimumDuration()
                        } else {
                            runPostSplashSetupIfNeeded()
                        }
                    }
                }
            }
            .tint(selectedTheme.accentColor)
            .preferredColorScheme(Self.forcedUITestColorScheme)
        }
        .modelContainer(modelContainer)
    }

    private var appContent: some View {
        ContentView(
            sharedHealthDataService: sharedHealthDataService,
            refreshCoordinator: refreshCoordinator
        )
        .sheet(isPresented: $showConsentSheet) {
            CloudSyncConsentView(isPresented: $showConsentSheet)
        }
    }

    #if DEBUG
    @ViewBuilder
    private var seedableAppContent: some View {
        appContent
            .task {
                guard !hasSeededMockData else { return }
                hasSeededMockData = true
                TestDataSeeder.seed(into: modelContainer.mainContext)
            }
    }
    #else
    // Stub to keep the `else if` branch compiling in Release builds.
    // shouldSeedMockData is always false outside XCTest, so this is unreachable.
    private var seedableAppContent: some View { appContent }
    #endif

    @MainActor
    private func runPostSplashSetupIfNeeded() {
        guard !hasCompletedPostSplashSetup else { return }
        hasCompletedPostSplashSetup = true

        if !hasShownConsent && !Self.isRunningXCTest {
            showConsentSheet = true
        }

        // Skip WC activation during XCTest to reduce startup flakiness.
        if !Self.isRunningXCTest {
            WatchSessionManager.shared.syncWorkoutTemplatesToWatch(using: modelContainer.mainContext)
            WatchSessionManager.shared.activate()
            observerManager?.startObserving()

            // Request notification authorization (non-blocking)
            Task {
                _ = await notificationService.requestAuthorization()
            }
        }
    }

    @MainActor
    private func dismissLaunchSplashAfterMinimumDuration() async {
        do {
            try await Task.sleep(for: Self.minimumLaunchSplashDuration)
        } catch is CancellationError {
            // Keep splash state unchanged when the task is cancelled.
            return
        } catch {
            return
        }

        guard !Task.isCancelled, isShowingLaunchSplash else { return }

        isResolvingLaunchSplash = true

        do {
            try await Task.sleep(for: Self.launchSplashResolveDuration)
        } catch is CancellationError {
            if isShowingLaunchSplash {
                isResolvingLaunchSplash = false
            }
            return
        } catch {
            if isShowingLaunchSplash {
                isResolvingLaunchSplash = false
            }
            return
        }

        guard !Task.isCancelled, isShowingLaunchSplash else { return }
        isShowingLaunchSplash = false
        isResolvingLaunchSplash = false
    }
}

private struct LaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isResolving: Bool

    private var backgroundDissolveAnimation: SwiftUI.Animation {
        if reduceMotion {
            return .easeOut(duration: 0.15)
        }
        return .easeOut(duration: 0.28)
    }

    private var logoDissolveAnimation: SwiftUI.Animation {
        if reduceMotion {
            return .easeOut(duration: 0.2)
        }
        return .timingCurve(0.22, 0.61, 0.36, 1.0, duration: 0.45).delay(0.18)
    }

    var body: some View {
        Color("LaunchBackground")
            .opacity(isResolving ? 0 : 1)
            .animation(backgroundDissolveAnimation, value: isResolving)
            .overlay {
                Image("LaunchLogo")
                    .opacity(isResolving ? 0 : 1)
                    .scaleEffect(isResolving ? 0.985 : 1)
                    .animation(logoDissolveAnimation, value: isResolving)
            }
            .ignoresSafeArea()
    }
}
