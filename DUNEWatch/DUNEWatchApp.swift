import SwiftUI
import SwiftData

@main
struct DUNEWatchApp: App {
    @State private var connectivity = WatchConnectivityManager.shared
    @State private var postureMonitor = WatchPostureMonitor.shared

    @Environment(\.scenePhase) private var scenePhase
    @State private var storeOpening: PersistentStoreOpening<ModelContainer>

    private static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting-watch")
    }

    private struct UITestLaunchConfiguration {
        let shouldResetState: Bool

        static func current(isRunningUITests: Bool) -> Self {
            guard isRunningUITests else {
                return Self(shouldResetState: false)
            }

            return Self(
                shouldResetState: ProcessInfo.processInfo.arguments.contains("--ui-reset")
            )
        }
    }

    private static let uiTestLaunchConfiguration = UITestLaunchConfiguration.current(
        isRunningUITests: isRunningUITests
    )

    private static func makeModelContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        // All migration stages are .lightweight — automatic migration handles them.
        // Staged plan removed due to drifted VersionedSchema hashes causing 134504.
        let container = try ModelContainer(for: AppSchema.currentSchema, configurations: configuration)
        HealthStoreBackupPolicy.refresh(container)
        return container
    }

    private static func openStore() -> PersistentStoreOpening<ModelContainer> {
        PersistentStoreOpening {
            let config = ModelConfiguration(
                isStoredInMemoryOnly: uiTestLaunchConfiguration.shouldResetState,
                cloudKitDatabase: .none
            )
            let container = try makeModelContainer(configuration: config)
            WatchConnectivityManager.shared.registeredModelContainer = container
            return container
        }
    }

    init() {
        _storeOpening = State(initialValue: Self.openStore())
    }

    /// Theme synced from iPhone via WatchConnectivity.
    /// Falls back to desertWarm if never synced.
    private var resolvedTheme: AppTheme {
        AppTheme.resolvedTheme(fromPersistedRawValue: connectivity.syncedThemeRawValue) ?? .desertWarm
    }

    var body: some Scene {
        WindowGroup {
            storeOpening.content(retry: { storeOpening = Self.openStore() }) { modelContainer in
                ContentView()
                    .workoutBackupWarnings()
                    .environment(connectivity)
                    .environment(\.appTheme, resolvedTheme)
                    .tint(resolvedTheme.accentColor)
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .background { HealthStoreBackupPolicy.refresh(modelContainer) }
                    }
                    .onAppear {
                        connectivity.activate()
                        postureMonitor.startMonitoringIfEnabled()
                    }
                    .modelContainer(modelContainer)
            }
        }
    }
}
