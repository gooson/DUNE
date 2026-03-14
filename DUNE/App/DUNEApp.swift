import SwiftUI
import SwiftData
import HealthKit
import UserNotifications

@main
struct DUNEApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
    @State private var isRequestingDeferredAuthorizations = false
    @State private var hasStartedRuntimeServices = false
    @State private var automaticWhatsNewPresentation: AutomaticWhatsNewPresentation?
    @State private var automaticWhatsNewPresentedBuild = ""
    @State private var hasForcedConsentPresentation = false
    @State private var hasForcedAutomaticWhatsNewPresentation = false

    @State private var appRuntime: AppRuntime
    private let notificationService: any NotificationService
    private let notificationCenterDelegate: AppNotificationCenterDelegate
    private let whatsNewManager = WhatsNewManager.shared
    private let whatsNewStore = WhatsNewStore.shared
    private static let minimumLaunchSplashDuration: Duration = .seconds(1)
    private static let launchSplashResolveDuration: Duration = .milliseconds(700)

    private struct AutomaticWhatsNewPresentation: Identifiable, Equatable {
        let id: String
        let build: String
        let releases: [WhatsNewReleaseData]
    }

    private struct AppRuntime {
        let revision = UUID()
        let cloudSyncEnabled: Bool
        let modelContainer: ModelContainer
        let sharedHealthDataService: SharedHealthDataService
        let refreshCoordinator: AppRefreshCoordinating
        let observerManager: HealthKitObserverManager?
        let scoreRefreshService: ScoreRefreshService
    }

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

    private static var isForceCloudSyncConsentUITest: Bool {
#if DEBUG
        TestDataSeeder.shouldForceCloudSyncConsent()
#else
        false
#endif
    }

    private static var shouldForceAutomaticWhatsNewForUITests: Bool {
        isRunningUITests && ProcessInfo.processInfo.arguments.contains("--force-automatic-whatsnew")
    }

    private static var shouldBypassLaunchExperienceForTests: Bool {
        isRunningXCTest && !isRunningLaunchPermissionUITest
    }

    private struct UITestLaunchConfiguration {
        let shouldResetState: Bool
        let shouldSeedMockData: Bool
        let scenario: UITestSeedScenario

        static func current(isRunningUITests: Bool, isRunningXCTest: Bool) -> Self {
            guard isRunningUITests else {
                return Self(
                    shouldResetState: false,
                    shouldSeedMockData: false,
                    scenario: .empty
                )
            }

            let arguments = ProcessInfo.processInfo.arguments
            let shouldSeedMockData = isRunningXCTest && arguments.contains("--seed-mock")
            let shouldResetState = arguments.contains("--ui-reset")

            let scenario = DUNEApp.launchArgumentValue(for: "--ui-scenario")
                .flatMap(UITestSeedScenario.init(rawValue:))
                ?? (shouldSeedMockData ? .defaultSeeded : .empty)

            return Self(
                shouldResetState: shouldResetState,
                shouldSeedMockData: shouldSeedMockData,
                scenario: scenario
            )
        }
    }

    nonisolated private static func launchArgumentValue(for key: String) -> String? {
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

    private static let uiTestLaunchConfiguration = UITestLaunchConfiguration.current(
        isRunningUITests: isRunningUITests,
        isRunningXCTest: isRunningXCTest
    )

    private static let shouldSeedMockData = uiTestLaunchConfiguration.shouldSeedMockData
    private static let shouldUseMirroredSnapshotServiceForUITests = uiTestLaunchConfiguration.shouldSeedMockData

    private static let shouldResetUITestState = uiTestLaunchConfiguration.shouldResetState

    private static func makeModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: AppMigrationPlan.currentSchema,
            migrationPlan: AppMigrationPlan.self,
            configurations: configuration
        )
    }

    private static func makeInMemoryFallbackContainer() -> ModelContainer {
        AppLogger.data.error("Falling back to in-memory ModelContainer due to persistent store failure")
        let fallbackConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            // Skip migration plan — in-memory stores have nothing to migrate.
            return try makeFreshModelContainer(configuration: fallbackConfiguration)
        } catch {
            // Absolute last resort — should never happen but prevents fatalError crash.
            AppLogger.data.error("In-memory ModelContainer failed: \(error). Creating minimal container.")
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: Schema([]), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }

    private static func makeAppRuntime(
        notificationService: any NotificationService,
        cloudSyncEnabled: Bool? = nil
    ) -> AppRuntime {
        let resolvedCloudSyncEnabled = cloudSyncEnabled ?? (Self.isRunningXCTest
            ? false
            : CloudSyncPreferenceStore.resolvedValue())
        let config = ModelConfiguration(
            isStoredInMemoryOnly: Self.shouldResetUITestState,
            cloudKitDatabase: (resolvedCloudSyncEnabled && !Self.isRunningXCTest) ? .automatic : .none
        )

        let modelContainer: ModelContainer
        do {
            modelContainer = try Self.makeModelContainer(configuration: config)
        } catch {
            AppLogger.data.error("ModelContainer failed: \(error)")
            modelContainer = Self.recoverModelContainer(after: error, configuration: config)
        }

        let healthKitAvailable = HKHealthStore.isHealthDataAvailable()
        let sharedHealthDataService: SharedHealthDataService
        if Self.shouldUseMirroredSnapshotServiceForUITests {
            sharedHealthDataService = CloudMirroredSharedHealthDataService(modelContainer: modelContainer)
        } else if healthKitAvailable {
            let baseSharedService: SharedHealthDataService = SharedHealthDataServiceImpl(healthKitManager: .shared)
            let mirrorStore: HealthSnapshotMirroring = HealthSnapshotMirrorStore(modelContainer: modelContainer)
            sharedHealthDataService = MirroringSharedHealthDataService(
                baseService: baseSharedService,
                mirrorStore: mirrorStore
            )
        } else {
            AppLogger.healthKit.info("HealthKit unavailable. Falling back to cloud mirrored snapshot service.")
            sharedHealthDataService = CloudMirroredSharedHealthDataService(modelContainer: modelContainer)
        }

        let refreshCoordinator = AppRefreshCoordinatorImpl(sharedHealthDataService: sharedHealthDataService)

        let observerManager: HealthKitObserverManager?
        if healthKitAvailable {
            let hkStore = HKHealthStore()
            let evaluator = BackgroundNotificationEvaluator(
                store: hkStore,
                notificationService: notificationService
            )
            observerManager = HealthKitObserverManager(
                store: hkStore,
                coordinator: refreshCoordinator,
                notificationEvaluator: evaluator
            )
        } else {
            observerManager = nil
        }

        let scoreRefreshService = ScoreRefreshService(modelContainer: modelContainer)

        return AppRuntime(
            cloudSyncEnabled: resolvedCloudSyncEnabled,
            modelContainer: modelContainer,
            sharedHealthDataService: sharedHealthDataService,
            refreshCoordinator: refreshCoordinator,
            observerManager: observerManager,
            scoreRefreshService: scoreRefreshService
        )
    }

    init() {
#if DEBUG
        if Self.shouldResetUITestState {
            TestDataSeeder.resetUserDefaults()
        }
#endif

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

        let notifService = NotificationServiceImpl()
        self.notificationService = notifService
        self.notificationCenterDelegate = AppNotificationCenterDelegate()
        UNUserNotificationCenter.current().delegate = notificationCenterDelegate
        _appRuntime = State(initialValue: Self.makeAppRuntime(notificationService: notifService))
    }

    private static func deleteStoreFiles(at url: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let fileURL = URL(fileURLWithPath: url.path + suffix)
            do {
                try fm.removeItem(at: fileURL)
                AppLogger.data.info("Deleted store file: \(fileURL.lastPathComponent)")
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileNoSuchFileError {
                // File doesn't exist — nothing to delete.
            } catch {
                AppLogger.data.error("Failed to delete store file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }

    /// Create a ModelContainer WITHOUT the migration plan.
    /// Used after store deletion when a fresh store needs no migration.
    /// The staged migration plan contains VersionedSchemas that reference live model
    /// types whose hashes have drifted since declaration (V2-V7, V11 reference live
    /// types later modified). This causes 134504 "unknown model version" even on empty
    /// stores. Bypassing the migration plan avoids plan-validation errors entirely.
    private static func makeFreshModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: AppMigrationPlan.currentSchema,
            configurations: configuration
        )
    }

    private static func recoverModelContainer(after error: Error, configuration: ModelConfiguration) -> ModelContainer {
        let reflectedError = String(reflecting: error)
        guard PersistentStoreRecovery.shouldDeleteStore(after: error) else {
            AppLogger.data.error("Skipping store deletion for non-migration container error: \(reflectedError, privacy: .private)")
            return makeInMemoryFallbackContainer()
        }

        AppLogger.data.error("Deleting persistent store after migration compatibility failure: \(reflectedError, privacy: .private)")
        deleteStoreFiles(at: configuration.url)

        // Retry 1: fresh container WITHOUT migration plan (deleted store needs no migration).
        do {
            let container = try makeFreshModelContainer(configuration: configuration)
            AppLogger.data.info("ModelContainer recovered with fresh store (no migration plan).")
            return container
        } catch {
            AppLogger.data.error("Fresh ModelContainer retry failed: \(error)")
        }

        // Retry 2: fresh container without CloudKit either.
        do {
            let noCloudConfig = ModelConfiguration(
                url: configuration.url,
                cloudKitDatabase: .none
            )
            let container = try makeFreshModelContainer(configuration: noCloudConfig)
            AppLogger.data.info("ModelContainer recovered without CloudKit. Data will sync on next runtime rebuild.")
            return container
        } catch {
            AppLogger.data.error("Fresh ModelContainer retry without CloudKit also failed: \(error)")
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
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await refreshAppRuntimeIfNeeded()
                    await requestDeferredAuthorizationsIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.mainThreadPublisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { notification in
                let shouldHandle = shouldHandleCloudSyncNotification(notification)
                guard shouldHandle else { return }
                Task { @MainActor in
                    await refreshAppRuntimeIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.mainThreadPublisher(for: .NSPersistentStoreRemoteChange)) { _ in
                Task { @MainActor in
                    await PersistentStoreRemoteChangeRefresh.request(using: appRuntime.refreshCoordinator)
                }
            }
        }
        .modelContainer(appRuntime.modelContainer)
    }

    private var appContent: some View {
        ContentView(
            sharedHealthDataService: appRuntime.sharedHealthDataService,
            refreshCoordinator: appRuntime.refreshCoordinator,
            scoreRefreshService: appRuntime.scoreRefreshService,
            launchExperienceReady: isLaunchExperienceReady,
            canLoadHealthKitData: canLoadHealthKitData
        )
        .id(appRuntime.revision)
        .sheet(isPresented: $showConsentSheet) {
            CloudSyncConsentView(isPresented: $showConsentSheet)
        }
        .sheet(item: $automaticWhatsNewPresentation, onDismiss: handleAutomaticWhatsNewDismissed) { presentation in
            NavigationStack {
                WhatsNewView(
                    releases: presentation.releases,
                    mode: .automatic
                )
            }
        }
        .task {
            guard Self.isForceCloudSyncConsentUITest else { return }
            guard !hasForcedConsentPresentation else { return }
            guard !showConsentSheet else { return }
            hasForcedConsentPresentation = true
            showConsentSheet = true
        }
        .task {
            guard Self.shouldForceAutomaticWhatsNewForUITests else { return }
            await forceAutomaticWhatsNewForUITestsIfNeeded()
        }
    }

    #if DEBUG
    @ViewBuilder
    private var seedableAppContent: some View {
        if hasSeededMockData {
            appContent
        } else {
            Color.clear
                .task {
                    guard !hasSeededMockData else { return }
                    TestDataSeeder.seed(
                        into: appRuntime.modelContainer.mainContext,
                        scenario: Self.uiTestLaunchConfiguration.scenario
                    )
                    hasSeededMockData = true
                }
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

    private func shouldHandleCloudSyncNotification(_ notification: Notification) -> Bool {
        guard let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return true
        }
        return changedKeys.contains(CloudSyncPreferenceStore.storageKey)
    }

    @MainActor
    private func refreshAppRuntimeIfNeeded() async {
        guard !Self.isRunningXCTest else { return }

        let resolvedValue = CloudSyncPreferenceStore.resolvedValue()
        let action = CloudSyncPreferenceStore.runtimeRefreshAction(
            currentValue: appRuntime.cloudSyncEnabled,
            resolvedValue: resolvedValue
        )

        guard case let .rebuild(resolvedValue: nextValue) = action else {
            return
        }

        let previousObserverManager = appRuntime.observerManager
        if let previousObserverManager {
            await previousObserverManager.stopObserving()
        }

        appRuntime = Self.makeAppRuntime(
            notificationService: notificationService,
            cloudSyncEnabled: nextValue
        )

        if isLaunchExperienceReady {
            hasStartedRuntimeServices = false
            startRuntimeServicesIfNeeded()
            Task {
                await appRuntime.refreshCoordinator.forceRefresh()
            }
        }
    }

    private var shouldRequestHealthKitAuthorizationAutomatically: Bool {
        LaunchExperiencePlanner.shouldRequestAuthorization(
            for: LaunchAuthorizationRequestState(
                isEligible: HKHealthStore.isHealthDataAvailable(),
                hasCompletedRequest: hasRequestedHealthKitAuthorization,
                hasAttemptedThisLaunch: hasAttemptedHealthKitAuthorizationThisLaunch,
                shouldBypassLaunchExperience: Self.shouldBypassLaunchExperienceForTests
            )
        )
    }

    private var shouldRequestNotificationAuthorizationAutomatically: Bool {
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

    private var canLoadHealthKitData: Bool {
        Self.shouldBypassLaunchExperienceForTests || hasRequestedHealthKitAuthorization
    }

    private var nextLaunchExperienceStep: LaunchExperienceStep {
        LaunchExperiencePlanner.nextStep(
            for: LaunchExperienceState(
                shouldBypassLaunchExperience: Self.shouldBypassLaunchExperienceForTests,
                hasShownCloudSyncConsent: hasShownConsent,
                shouldPresentWhatsNew: shouldPresentAutomaticWhatsNew
            )
        )
    }

    private var isShowingAutomaticWhatsNew: Bool {
        automaticWhatsNewPresentation != nil
    }

    @MainActor
    private func advanceLaunchExperienceFlowIfNeeded() async {
        guard hasCompletedPostSplashSetup else { return }
        guard !isAdvancingLaunchExperience else { return }
        guard !showConsentSheet, !isShowingAutomaticWhatsNew else { return }

        isAdvancingLaunchExperience = true
        defer { isAdvancingLaunchExperience = false }

        while hasCompletedPostSplashSetup, !showConsentSheet, !isShowingAutomaticWhatsNew {
            switch nextLaunchExperienceStep {
            case .cloudSyncConsent:
                showConsentSheet = true
                return
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

        let releases = whatsNewManager.orderedReleases(preferredVersion: currentRelease.version)
        guard !releases.isEmpty else {
            finishLaunchExperienceIfNeeded()
            return
        }

        automaticWhatsNewPresentedBuild = build
        automaticWhatsNewPresentation = AutomaticWhatsNewPresentation(
            id: build,
            build: build,
            releases: releases
        )
    }

    @MainActor
    private func handleAutomaticWhatsNewDismissed() {
        if !automaticWhatsNewPresentedBuild.isEmpty {
            whatsNewStore.markOpened(build: automaticWhatsNewPresentedBuild)
        }

        automaticWhatsNewPresentedBuild = ""

        Task { await advanceLaunchExperienceFlowIfNeeded() }
    }

    @MainActor
    private func forceAutomaticWhatsNewForUITestsIfNeeded() async {
        guard !hasForcedAutomaticWhatsNewPresentation else { return }
        guard automaticWhatsNewPresentation == nil else { return }

        let version = whatsNewManager.currentAppVersion()
        let preferredVersion = whatsNewManager.currentRelease(for: version)?.version
            ?? whatsNewManager.orderedReleases().first?.version
        guard let preferredVersion else { return }

        let releases = whatsNewManager.orderedReleases(preferredVersion: preferredVersion)
        guard !releases.isEmpty else { return }

        let build = whatsNewManager.currentBuildNumber()
        hasForcedAutomaticWhatsNewPresentation = true
        automaticWhatsNewPresentedBuild = build
        automaticWhatsNewPresentation = AutomaticWhatsNewPresentation(
            id: build.isEmpty ? preferredVersion : build,
            build: build,
            releases: releases
        )
    }

    @MainActor
    private func finishLaunchExperienceIfNeeded() {
        guard !isLaunchExperienceReady else { return }

        isLaunchExperienceReady = true
        startRuntimeServicesIfNeeded()
        Task { await requestDeferredAuthorizationsIfNeeded() }
    }

    @MainActor
    private func startRuntimeServicesIfNeeded() {
        guard !hasStartedRuntimeServices else { return }
        guard !Self.shouldBypassLaunchExperienceForTests else { return }

        hasStartedRuntimeServices = true
        let modelContainer = appRuntime.modelContainer
        WatchSessionManager.shared.registerModelContainer(modelContainer)
        WatchSessionManager.shared.syncWorkoutTemplatesToWatch(using: modelContainer)
        WatchSessionManager.shared.syncExerciseLibraryToWatch(using: modelContainer)
        WatchSessionManager.shared.activate()
        appRuntime.observerManager?.startObserving()
        appRuntime.scoreRefreshService.startListening(to: appRuntime.refreshCoordinator)
        Task {
            await BedtimeReminderScheduler.shared.refreshSchedule()
        }
        scheduleWorkoutTitleBackfill()
    }

    @MainActor
    private func requestDeferredAuthorizationsIfNeeded() async {
        guard isLaunchExperienceReady else { return }
        guard scenePhase == .active else { return }
        guard !Self.shouldBypassLaunchExperienceForTests else { return }
        guard !isRequestingDeferredAuthorizations else { return }
        guard shouldRequestHealthKitAuthorizationAutomatically || shouldRequestNotificationAuthorizationAutomatically else {
            return
        }

        isRequestingDeferredAuthorizations = true
        defer { isRequestingDeferredAuthorizations = false }

        try? await Task.sleep(for: .milliseconds(400))
        guard scenePhase == .active else { return }

        if shouldRequestHealthKitAuthorizationAutomatically {
            hasAttemptedHealthKitAuthorizationThisLaunch = true
            do {
                try await HealthKitManager.shared.requestAuthorization()
                hasRequestedHealthKitAuthorization = true
            } catch {
                AppLogger.healthKit.error("Deferred HealthKit authorization failed: \(error.localizedDescription)")
            }
        }

        if shouldRequestNotificationAuthorizationAutomatically {
            hasAttemptedNotificationAuthorizationThisLaunch = true
            do {
                let granted = try await notificationService.requestAuthorization()
                hasRequestedNotificationAuthorization = true
                if granted {
                    await BedtimeReminderScheduler.shared.refreshSchedule(force: true)
                }
            } catch {
                AppLogger.notification.error("Deferred notification authorization failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func scheduleWorkoutTitleBackfill() {
        let container = appRuntime.modelContainer
        Task(priority: .utility) {
            do {
                let context = ModelContext(container)
                let records = try context.fetch(FetchDescriptor<ExerciseRecord>())
                WorkoutTypeCorrectionStore.shared.backfillTitles(from: records)
            } catch {
                AppLogger.data.error("Workout title backfill failed: \(error.localizedDescription)")
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
