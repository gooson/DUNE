import SwiftUI

/// visionOS main navigation view.
/// Uses standard TabView which renders as a left-side vertical tab bar on visionOS.
/// Glass material is applied automatically by the system.
struct VisionContentView: View {
    private let sharedHealthDataService: SharedHealthDataService?
    private let refreshCoordinator: AppRefreshCoordinating?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @State private var selectedSection: AppSection = .today
    @State private var refreshSignal = 0
    @State private var foregroundTask: Task<Void, Never>?

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        refreshCoordinator: AppRefreshCoordinating? = nil
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.refreshCoordinator = refreshCoordinator
    }

    var body: some View {
        TabView(selection: $selectedSection) {
            Tab(value: AppSection.today) {
                NavigationStack {
                    VisionDashboardView(
                        sharedHealthDataService: sharedHealthDataService,
                        refreshSignal: refreshSignal,
                        onOpen3DCharts: { openWindow(id: "chart3d") }
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
                    ActivityView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: 0,
                        refreshSignal: refreshSignal,
                        notificationWorkoutID: nil,
                        notificationRouteSignal: 0,
                        notificationPersonalRecordsSignal: 0
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
                    WellnessView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: 0,
                        refreshSignal: refreshSignal
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
                    LifeView(
                        scrollToTopSignal: 0,
                        refreshSignal: refreshSignal
                    )
                }
            } label: {
                Label {
                    Text(verbatim: AppSection.life.title)
                } icon: {
                    Image(systemName: AppSection.life.icon)
                }
            }
        }
        .environment(\.appTheme, selectedTheme)
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
}
