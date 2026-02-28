import SwiftUI

struct ContentView: View {
    private let sharedHealthDataService: SharedHealthDataService?
    private let refreshCoordinator: AppRefreshCoordinating?
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSection: AppSection = .today
    @State private var todayScrollToTopSignal = 0
    @State private var activityScrollToTopSignal = 0
    @State private var wellnessScrollToTopSignal = 0
    @State private var refreshSignal = 0

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        refreshCoordinator: AppRefreshCoordinating? = nil
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.refreshCoordinator = refreshCoordinator
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab(AppSection.today.title, systemImage: AppSection.today.icon, value: AppSection.today) {
                NavigationStack {
                    DashboardView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: todayScrollToTopSignal,
                        refreshSignal: refreshSignal
                    )
                }
                .environment(\.wavePreset, .today)
                .environment(\.waveColor, DS.Color.warmGlow)
            }
            Tab(AppSection.train.title, systemImage: AppSection.train.icon, value: AppSection.train) {
                NavigationStack {
                    ActivityView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: activityScrollToTopSignal,
                        refreshSignal: refreshSignal
                    )
                }
                .environment(\.wavePreset, .train)
                .environment(\.waveColor, DS.Color.tabTrain)
            }
            Tab(AppSection.wellness.title, systemImage: AppSection.wellness.icon, value: AppSection.wellness) {
                NavigationStack {
                    WellnessView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: wellnessScrollToTopSignal,
                        refreshSignal: refreshSignal
                    )
                }
                .environment(\.wavePreset, .wellness)
                .environment(\.waveColor, DS.Color.tabWellness)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Foreground refresh: scenePhase .background → .active (Correction #60: specific transition only)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase == .active {
                Task {
                    _ = await refreshCoordinator?.requestRefresh(source: .foreground)
                    // UI update is handled by refreshNeededStream listener below
                }
            }
        }
        // Listen for refresh signals from coordinator (foreground + HK observer triggers)
        .task {
            guard let coordinator = refreshCoordinator else { return }
            for await _ in coordinator.refreshNeededStream {
                refreshSignal += 1
            }
        }
    }

    private var tabSelection: Binding<AppSection> {
        Binding(
            get: { selectedSection },
            set: { newValue in
                if selectedSection == newValue {
                    switch newValue {
                    case .today:
                        todayScrollToTopSignal += 1
                    case .train:
                        activityScrollToTopSignal += 1
                    case .wellness:
                        wellnessScrollToTopSignal += 1
                    }
                }
                selectedSection = newValue
            }
        )
    }
}

#Preview {
    ContentView()
}
