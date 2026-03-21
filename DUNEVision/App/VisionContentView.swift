import SwiftUI
import SwiftData

/// visionOS main navigation view.
/// Uses standard TabView which renders as a left-side vertical tab bar on visionOS.
/// Glass material is applied automatically by the system.
struct VisionContentView: View {
    private static let windowPlacementSmokeInitialDelayNanos: UInt64 = 800_000_000
    private static let windowPlacementSmokeStepDelayNanos: UInt64 = 350_000_000
    private static let windowPlacementSmokeDismissDelayNanos: UInt64 = 350_000_000
    private static let windowPlacementSmokeManagedWindowIDs = [
        VisionDashboardWindowKind.condition.windowID,
        VisionDashboardWindowKind.activity.windowID,
        VisionDashboardWindowKind.sleep.windowID,
        VisionDashboardWindowKind.body.windowID,
        VisionWindowPlacementPlanner.settingsWindowID,
        VisionWindowPlacementPlanner.chart3DWindowID,
        "spatial-volume",
    ]

    @AppStorage(SimulatorAdvancedMockDataModeStore.storageKey) private var isSimulatorMockEnabled = false
    private let modelContainer: ModelContainer
    private let sharedHealthDataService: SharedHealthDataService?
    private let refreshCoordinator: AppRefreshCoordinating?
    private let workoutService: WorkoutQuerying
    private let windowPlacementSmokeConfiguration: VisionWindowPlacementSmokeConfiguration
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @State private var selectedSection: AppSection = .today
    // Phase 4: refreshSignal will propagate live-data updates to child views
    @State private var refreshSignal = 0
    @State private var foregroundTask: Task<Void, Never>?
    @State private var showSettings = false
    @State private var trainViewModel: VisionTrainViewModel
    @State private var isProcessingSimulatorMockData = false
    @State private var simulatorMockStatusMessage: String?

    init(
        modelContainer: ModelContainer,
        sharedHealthDataService: SharedHealthDataService? = nil,
        refreshCoordinator: AppRefreshCoordinating? = nil,
        workoutService: WorkoutQuerying
    ) {
        self.modelContainer = modelContainer
        self.sharedHealthDataService = sharedHealthDataService
        self.refreshCoordinator = refreshCoordinator
        self.workoutService = workoutService
        self.windowPlacementSmokeConfiguration = .current()
        _trainViewModel = State(wrappedValue: VisionTrainViewModel(
            sharedHealthDataService: sharedHealthDataService,
            workoutService: workoutService
        ))
    }

    var body: some View {
        TabView(selection: $selectedSection) {
            Tab(value: AppSection.today) {
                NavigationStack {
                    VisionDashboardView(
                        sharedHealthDataService: sharedHealthDataService,
                        refreshSignal: refreshSignal,
                        isSimulatorMockEnabled: isSimulatorMockEnabled,
                        simulatorMockStatusMessage: simulatorMockStatusMessage,
                        onOpenSettings: {
                            if supportsMultipleWindows {
                                scheduleWindowOpen(VisionWindowPlacementPlanner.settingsWindowID)
                            } else {
                                showSettings = true
                            }
                        },
                        onOpenDashboardWindow: { windowKind in
                            guard supportsMultipleWindows else { return }
                            scheduleWindowOpen(windowKind.windowID)
                        },
                        onOpen3DCharts: {
                            guard supportsMultipleWindows else { return }
                            scheduleWindowOpen("chart3d")
                        },
                        onOpenVolumetric: {
                            guard supportsMultipleWindows else { return }
                            scheduleWindowOpen("spatial-volume")
                        },
                        onOpenImmersive: {
                            scheduleImmersiveOpen()
                        },
                        onSeedAdvancedMockData: {
                            seedAdvancedMockData()
                        },
                        onResetAdvancedMockData: {
                            resetAdvancedMockData()
                        }
                    )
                    .navigationDestination(isPresented: $showSettings) {
                        VisionSettingsView(
                            modelContainer: modelContainer,
                            smokeConfiguration: windowPlacementSmokeConfiguration
                        )
                    }
                }
                .accessibilityIdentifier(VisionSurfaceAccessibility.sectionScreenID(for: .today))
            } label: {
                Label {
                    Text(verbatim: AppSection.today.title)
                } icon: {
                    Image(systemName: AppSection.today.icon)
                }
            }
            Tab(value: AppSection.train) {
                NavigationStack {
                    VisionTrainView(
                        viewModel: trainViewModel,
                        onOpen3DCharts: {
                            guard supportsMultipleWindows else { return }
                            scheduleWindowOpen("chart3d")
                        }
                    )
                }
                .accessibilityIdentifier(VisionSurfaceAccessibility.sectionScreenID(for: .train))
            } label: {
                Label {
                    Text(verbatim: AppSection.train.title)
                } icon: {
                    Image(systemName: AppSection.train.icon)
                }
            }
            Tab(value: AppSection.wellness) {
                NavigationStack {
                    VisionWellnessView(
                        sharedHealthDataService: sharedHealthDataService,
                        refreshSignal: refreshSignal
                    )
                }
                .accessibilityIdentifier(VisionSurfaceAccessibility.sectionScreenID(for: .wellness))
            } label: {
                Label {
                    Text(verbatim: AppSection.wellness.title)
                } icon: {
                    Image(systemName: AppSection.wellness.icon)
                }
            }
            Tab(value: AppSection.life) {
                NavigationStack {
                    VisionLifeView()
                }
                .accessibilityIdentifier(VisionSurfaceAccessibility.sectionScreenID(for: .life))
            } label: {
                Label {
                    Text(verbatim: AppSection.life.title)
                } icon: {
                    Image(systemName: AppSection.life.icon)
                }
            }
        }
        .accessibilityIdentifier(VisionSurfaceAccessibility.contentRoot)
        .onDisappear { foregroundTask?.cancel() }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase == .active {
                foregroundTask?.cancel()
                foregroundTask = Task {
                    _ = await refreshCoordinator?.requestRefresh(source: .foreground)
                }
            }
        }
        .onReceive(NotificationCenter.default.mainThreadPublisher(for: .simulatorAdvancedMockDataDidChange)) { _ in
            Task { @MainActor in
                if let refreshCoordinator {
                    await refreshCoordinator.forceRefresh()
                } else {
                    await sharedHealthDataService?.invalidateCache()
                    refreshSignal += 1
                }
                await trainViewModel.reload()
            }
        }
        .task(id: windowPlacementSmokeConfiguration) {
            await runWindowPlacementSmokeIfNeeded()
        }
        .task {
            guard let coordinator = refreshCoordinator else { return }
            for await _ in coordinator.refreshNeededStream {
                await MainActor.run {
                    refreshSignal += 1
                }
            }
        }
    }

    @MainActor
    private func runWindowPlacementSmokeIfNeeded() async {
        guard windowPlacementSmokeConfiguration.isEnabled else { return }
        guard supportsMultipleWindows else {
            AppLogger.ui.info("[VisionWindowPlacementSmoke] Multiple windows unsupported; skipping smoke flow")
            return
        }

        if windowPlacementSmokeConfiguration.shouldSeedMockData {
            applyAdvancedMockDataSeed()
        }

        try? await Task.sleep(nanoseconds: Self.windowPlacementSmokeInitialDelayNanos)
        dismissExistingSmokeWindows()
        try? await Task.sleep(nanoseconds: Self.windowPlacementSmokeStepDelayNanos)

        for windowID in windowPlacementSmokeConfiguration.mainWindowAutoOpenIDs {
            guard !Task.isCancelled else { return }
            AppLogger.ui.info("[VisionWindowPlacementSmoke] Opening \(windowID)")
            openWindow(id: windowID)
            try? await Task.sleep(nanoseconds: Self.windowPlacementSmokeStepDelayNanos)
        }

        guard windowPlacementSmokeConfiguration.shouldDismissMainWindow else { return }
        try? await Task.sleep(nanoseconds: Self.windowPlacementSmokeDismissDelayNanos)
        AppLogger.ui.info("[VisionWindowPlacementSmoke] Dismissing main window for no-anchor fallback")
        dismissWindow()
    }

    @MainActor
    private func dismissExistingSmokeWindows() {
        for windowID in Self.windowPlacementSmokeManagedWindowIDs {
            dismissWindow(id: windowID)
        }
    }

    private func scheduleWindowOpen(_ id: String) {
        Task { @MainActor in
            await Task.yield()
            openWindow(id: id)
        }
    }

    private func scheduleImmersiveOpen() {
        Task { @MainActor in
            await Task.yield()
            let result = await openImmersiveSpace(id: "immersive-recovery")
            if result == .error {
                AppLogger.ui.error("Immersive space failed to open")
            }
        }
    }

    private func seedAdvancedMockData() {
        Task { @MainActor in
            applyAdvancedMockDataSeed()
        }
    }

    @MainActor
    private func applyAdvancedMockDataSeed() {
        guard SimulatorAdvancedMockDataModeStore.isSimulatorAvailable else { return }
        guard !isProcessingSimulatorMockData else { return }
        isProcessingSimulatorMockData = true
        simulatorMockStatusMessage = nil

        defer { isProcessingSimulatorMockData = false }
        do {
            try SimulatorAdvancedMockDataProvider.seed(into: ModelContext(modelContainer))
            isSimulatorMockEnabled = true
            simulatorMockStatusMessage = String(localized: "Mock data seeded.")
        } catch {
            simulatorMockStatusMessage = String(localized: "Mock data could not be updated.")
            AppLogger.data.error("Vision simulator mock data seed failed: \(error.localizedDescription)")
        }
    }

    private func resetAdvancedMockData() {
        Task { @MainActor in
            applyAdvancedMockDataReset()
        }
    }

    @MainActor
    private func applyAdvancedMockDataReset() {
        guard SimulatorAdvancedMockDataModeStore.isSimulatorAvailable else { return }
        guard !isProcessingSimulatorMockData else { return }
        isProcessingSimulatorMockData = true
        simulatorMockStatusMessage = nil

        defer { isProcessingSimulatorMockData = false }
        do {
            try SimulatorAdvancedMockDataProvider.reset(into: ModelContext(modelContainer))
            isSimulatorMockEnabled = false
            simulatorMockStatusMessage = String(localized: "Mock data reset.")
        } catch {
            simulatorMockStatusMessage = String(localized: "Mock data could not be updated.")
            AppLogger.data.error("Vision simulator mock data reset failed: \(error.localizedDescription)")
        }
    }
}
