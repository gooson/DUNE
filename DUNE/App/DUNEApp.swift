import SwiftUI
import SwiftData
import HealthKit
import UserNotifications

@main
struct DUNEApp: App {
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @AppStorage("hasShownCloudSyncConsent") private var hasShownConsent = false
    @AppStorage("hasRequestedHealthKitAuthorization") private var hasRequestedHealthKitAuthorization = false
    @AppStorage("hasRequestedNotificationAuthorization") private var hasRequestedNotificationAuthorization = false
    @State private var showConsentSheet = false
    @State private var isShowingLaunchSplash = !DUNEApp.isRunningXCTest
    @State private var isResolvingLaunchSplash = false
    @State private var hasCompletedPostSplashSetup = false
    @State private var hasSeededMockData = false
    @State private var isLaunchExperienceReady = DUNEApp.shouldBypassLaunchExperienceForTests || DUNEApp.shouldSeedMockData
    @State private var isAdvancingLaunchExperience = false
    @State private var hasAttemptedHealthKitAuthorizationThisLaunch = false
    @State private var hasAttemptedNotificationAuthorizationThisLaunch = false
    @State private var hasStartedRuntimeServices = false
    @State private var showWhatsNewSheet = false
    @State private var automaticWhatsNewReleases: [WhatsNewRelease] = []
    @State private var automaticWhatsNewBuild = ""

    let modelContainer: ModelContainer
    private let sharedHealthDataService: SharedHealthDataService
    private let refreshCoordinator: AppRefreshCoordinating
    private let observerManager: HealthKitObserverManager?
    private let notificationService: any NotificationService
    private let notificationCenterDelegate: AppNotificationCenterDelegate
    private let whatsNewManager = WhatsNewManager.shared
    private let whatsNewStore = WhatsNewStore.shared
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

    private static var isRunningLaunchPermissionUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("--healthkit-permission-uitest")
    }

    private static var shouldBypassLaunchExperienceForTests: Bool {
        isRunningXCTest && !isRunningLaunchPermissionUITest
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
        let persistedThemeRawValue = UserDefaults.standard.string(forKey: AppTheme.storageKey)
        if let normalizedTheme = AppTheme.resolvedTheme(fromPersistedRawValue: persistedThemeRawValue) {
            if persistedThemeRawValue != normalizedTheme.rawValue {
                UserDefaults.standard.set(normalizedTheme.rawValue, forKey: AppTheme.storageKey)
            }
            _selectedTheme = AppStorage(wrappedValue: normalizedTheme, AppTheme.storageKey)
        }

        if let forcedTheme = Self.forcedUITestTheme {
            UserDefaults.standard.set(forcedTheme.rawValue, forKey: AppTheme.storageKey)
            _selectedTheme = AppStorage(wrappedValue: forcedTheme, AppTheme.storageKey)
        }
        let cloudSyncEnabled = UserDefaults.standard.bool(forKey: "isCloudSyncEnabled")
        let config = ModelConfiguration(
            cloudKitDatabase: (cloudSyncEnabled && !Self.isRunningXCTest) ? .automatic : .none
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
            .onChange(of: showConsentSheet) { oldValue, newValue in
                guard oldValue, !newValue else { return }
                Task { await advanceLaunchExperienceFlowIfNeeded() }
            }
        }
        .modelContainer(modelContainer)
    }

    private var appContent: some View {
        ContentView(
            sharedHealthDataService: sharedHealthDataService,
            refreshCoordinator: refreshCoordinator,
            launchExperienceReady: isLaunchExperienceReady,
            shouldAutoRequestHealthKitAuthorization: shouldRequestHealthKitAuthorizationOnLaunch
        )
        .sheet(isPresented: $showConsentSheet) {
            CloudSyncConsentView(isPresented: $showConsentSheet)
        }
        .sheet(isPresented: $showWhatsNewSheet, onDismiss: handleAutomaticWhatsNewDismissed) {
            NavigationStack {
                WhatsNewView(
                    releases: automaticWhatsNewReleases,
                    mode: .automatic
                )
            }
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
        Task { await advanceLaunchExperienceFlowIfNeeded() }
    }

    private var shouldRequestHealthKitAuthorizationOnLaunch: Bool {
        LaunchExperiencePlanner.shouldRequestAuthorization(
            for: LaunchAuthorizationRequestState(
                isEligible: HKHealthStore.isHealthDataAvailable(),
                hasCompletedRequest: hasRequestedHealthKitAuthorization,
                hasAttemptedThisLaunch: hasAttemptedHealthKitAuthorizationThisLaunch,
                shouldBypassLaunchExperience: Self.shouldBypassLaunchExperienceForTests
            )
        )
    }

    private var shouldRequestNotificationAuthorizationOnLaunch: Bool {
        LaunchExperiencePlanner.shouldRequestAuthorization(
            for: LaunchAuthorizationRequestState(
                isEligible: true,
                hasCompletedRequest: hasRequestedNotificationAuthorization,
                hasAttemptedThisLaunch: hasAttemptedNotificationAuthorizationThisLaunch,
                shouldBypassLaunchExperience: Self.shouldBypassLaunchExperienceForTests
            )
        )
    }

    private var shouldPresentAutomaticWhatsNew: Bool {
        guard !Self.shouldBypassLaunchExperienceForTests else { return false }

        let version = whatsNewManager.currentAppVersion()
        let build = whatsNewManager.currentBuildNumber()
        guard !build.isEmpty,
              whatsNewManager.currentRelease(for: version) != nil else {
            return false
        }

        return whatsNewStore.shouldShowBadge(build: build)
    }

    private var nextLaunchExperienceStep: LaunchExperienceStep {
        LaunchExperiencePlanner.nextStep(
            for: LaunchExperienceState(
                shouldBypassLaunchExperience: Self.shouldBypassLaunchExperienceForTests,
                hasShownCloudSyncConsent: hasShownConsent,
                shouldRequestHealthKitAuthorization: shouldRequestHealthKitAuthorizationOnLaunch,
                shouldRequestNotificationAuthorization: shouldRequestNotificationAuthorizationOnLaunch,
                shouldPresentWhatsNew: shouldPresentAutomaticWhatsNew
            )
        )
    }

    @MainActor
    private func advanceLaunchExperienceFlowIfNeeded() async {
        guard hasCompletedPostSplashSetup else { return }
        guard !isAdvancingLaunchExperience else { return }
        guard !showConsentSheet, !showWhatsNewSheet else { return }

        isAdvancingLaunchExperience = true
        defer { isAdvancingLaunchExperience = false }

        while hasCompletedPostSplashSetup, !showConsentSheet, !showWhatsNewSheet {
            switch nextLaunchExperienceStep {
            case .cloudSyncConsent:
                showConsentSheet = true
                return
            case .healthKitAuthorization:
                hasAttemptedHealthKitAuthorizationThisLaunch = true
                do {
                    try await HealthKitManager.shared.requestAuthorization()
                    hasRequestedHealthKitAuthorization = true
                } catch {
                    AppLogger.healthKit.error("Launch HealthKit authorization failed: \(error.localizedDescription)")
                }
            case .notificationAuthorization:
                hasAttemptedNotificationAuthorizationThisLaunch = true
                do {
                    _ = try await notificationService.requestAuthorization()
                    hasRequestedNotificationAuthorization = true
                } catch {
                    AppLogger.notification.error("Launch notification authorization failed: \(error.localizedDescription)")
                }
            case .whatsNew:
                presentAutomaticWhatsNewIfNeeded()
                return
            case .ready:
                finishLaunchExperienceIfNeeded()
                return
            }
        }
    }

    @MainActor
    private func presentAutomaticWhatsNewIfNeeded() {
        let version = whatsNewManager.currentAppVersion()
        let build = whatsNewManager.currentBuildNumber()

        guard !build.isEmpty,
              let currentRelease = whatsNewManager.currentRelease(for: version),
              whatsNewStore.shouldShowBadge(build: build) else {
            finishLaunchExperienceIfNeeded()
            return
        }

        automaticWhatsNewBuild = build
        automaticWhatsNewReleases = whatsNewManager.orderedReleases(preferredVersion: currentRelease.version)
        showWhatsNewSheet = true
    }

    @MainActor
    private func handleAutomaticWhatsNewDismissed() {
        if !automaticWhatsNewBuild.isEmpty {
            whatsNewStore.markOpened(build: automaticWhatsNewBuild)
        }

        automaticWhatsNewBuild = ""
        automaticWhatsNewReleases = []

        Task { await advanceLaunchExperienceFlowIfNeeded() }
    }

    @MainActor
    private func finishLaunchExperienceIfNeeded() {
        guard !isLaunchExperienceReady else { return }

        isLaunchExperienceReady = true
        startRuntimeServicesIfNeeded()
    }

    @MainActor
    private func startRuntimeServicesIfNeeded() {
        guard !hasStartedRuntimeServices else { return }
        guard !Self.shouldBypassLaunchExperienceForTests else { return }

        hasStartedRuntimeServices = true
        WatchSessionManager.shared.syncWorkoutTemplatesToWatch(using: modelContainer)
        WatchSessionManager.shared.activate()
        observerManager?.startObserving()
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
