import SwiftUI

/// visionOS main navigation view.
/// Uses standard TabView which renders as a left-side vertical tab bar on visionOS.
/// Glass material is applied automatically by the system.
struct VisionContentView: View {
    private let sharedHealthDataService: SharedHealthDataService?
    private let refreshCoordinator: AppRefreshCoordinating?
    private let workoutService: WorkoutQuerying?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @State private var selectedSection: AppSection = .today
    // Phase 4: refreshSignal will propagate live-data updates to child views
    @State private var refreshSignal = 0
    @State private var foregroundTask: Task<Void, Never>?
    @State private var trainViewModel: VisionTrainViewModel

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        refreshCoordinator: AppRefreshCoordinating? = nil,
        workoutService: WorkoutQuerying? = nil
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.refreshCoordinator = refreshCoordinator
        self.workoutService = workoutService
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
                        }
                    )
                }
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
                        sharedHealthDataService: sharedHealthDataService
                    )
                }
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
            } label: {
                Label {
                    Text(verbatim: AppSection.life.title)
                } icon: {
                    Image(systemName: AppSection.life.icon)
                }
            }
        }
        .onDisappear { foregroundTask?.cancel() }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase == .active {
                foregroundTask?.cancel()
                foregroundTask = Task {
                    _ = await refreshCoordinator?.requestRefresh(source: .foreground)
                }
            }
        }
        .task {
            guard let coordinator = refreshCoordinator else { return }
            for await _ in coordinator.refreshNeededStream {
                refreshSignal += 1
            }
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
}
