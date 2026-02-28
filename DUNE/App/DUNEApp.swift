import SwiftUI
import SwiftData
import HealthKit

@main
struct DUNEApp: App {
    @AppStorage("hasShownCloudSyncConsent") private var hasShownConsent = false
    @State private var showConsentSheet = false
    @State private var isShowingLaunchSplash = !DUNEApp.isRunningXCTest
    @State private var isResolvingLaunchSplash = false
    @State private var hasCompletedPostSplashSetup = false
    @State private var hasSeededMockData = false

    let modelContainer: ModelContainer
    private let sharedHealthDataService: SharedHealthDataService
    private let refreshCoordinator: AppRefreshCoordinating
    private let observerManager: HealthKitObserverManager
    private static let minimumLaunchSplashDuration: Duration = .seconds(1)
    private static let launchSplashResolveDuration: Duration = .milliseconds(700)

    private static var isRunningXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private static var isRunningUITests: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--uitesting") || arguments.contains("--healthkit-permission-uitest")
    }

    private static var isRunningUnitTests: Bool {
        isRunningXCTest && !isRunningUITests
    }

    private static let shouldSeedMockData: Bool =
        isRunningXCTest && ProcessInfo.processInfo.arguments.contains("--seed-mock")

    init() {
        let sharedService: SharedHealthDataService = SharedHealthDataServiceImpl(healthKitManager: .shared)
        self.sharedHealthDataService = sharedService
        let coordinator = AppRefreshCoordinatorImpl(sharedHealthDataService: sharedService)
        self.refreshCoordinator = coordinator
        self.observerManager = HealthKitObserverManager(
            store: HKHealthStore(),
            coordinator: coordinator
        )
        let cloudSyncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")
        let config = ModelConfiguration(
            cloudKitDatabase: (cloudSyncEnabled && !Self.isRunningXCTest) ? .automatic : .none
        )
        do {
            modelContainer = try ModelContainer(
                for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, UserCategory.self, InjuryRecord.self, ExerciseDefaultRecord.self, HabitDefinition.self, HabitLog.self,
                migrationPlan: AppMigrationPlan.self,
                configurations: config
            )
        } catch {
            // Schema migration failed — delete store and retry (MVP: no user data to preserve)
            AppLogger.data.error("ModelContainer failed: \(error)")
            Self.deleteStoreFiles(at: config.url)
            do {
                modelContainer = try ModelContainer(
                    for: ExerciseRecord.self, BodyCompositionRecord.self, WorkoutSet.self, CustomExercise.self, WorkoutTemplate.self, UserCategory.self, InjuryRecord.self, ExerciseDefaultRecord.self, HabitDefinition.self, HabitLog.self,
                    migrationPlan: AppMigrationPlan.self,
                    configurations: config
                )
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
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
            .tint(DS.Color.warmGlow)
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
            WatchSessionManager.shared.activate()
            observerManager.startObserving()
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
