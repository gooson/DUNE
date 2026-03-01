import SwiftUI

struct ContentView: View {
    private let sharedHealthDataService: SharedHealthDataService?
    private let refreshCoordinator: AppRefreshCoordinating?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("com.dune.app.theme") private var selectedTheme: AppTheme = .desertWarm
    @State private var selectedSection: AppSection = .today
    @State private var todayScrollToTopSignal = 0
    @State private var activityScrollToTopSignal = 0
    @State private var wellnessScrollToTopSignal = 0
    @State private var lifeScrollToTopSignal = 0
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
        TabView(selection: tabSelection) {
            Tab(value: AppSection.today) {
                NavigationStack {
                    DashboardView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: todayScrollToTopSignal,
                        refreshSignal: refreshSignal
                    )
                }
                .environment(\.wavePreset, .today)
                .environment(\.waveColor, selectedTheme.tabTodayColor)
            } label: {
                Label { Text(verbatim: AppSection.today.title) } icon: { Image(systemName: AppSection.today.icon) }
            }
            Tab(value: AppSection.train) {
                NavigationStack {
                    ActivityView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: activityScrollToTopSignal,
                        refreshSignal: refreshSignal
                    )
                }
                .environment(\.wavePreset, .train)
                .environment(\.waveColor, selectedTheme.tabTrainColor)
            } label: {
                Label { Text(verbatim: AppSection.train.title) } icon: { Image(systemName: AppSection.train.icon) }
            }
            Tab(value: AppSection.wellness) {
                NavigationStack {
                    WellnessView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: wellnessScrollToTopSignal,
                        refreshSignal: refreshSignal
                    )
                }
                .environment(\.wavePreset, .wellness)
                .environment(\.waveColor, selectedTheme.tabWellnessColor)
            } label: {
                Label { Text(verbatim: AppSection.wellness.title) } icon: { Image(systemName: AppSection.wellness.icon) }
            }
            Tab(value: AppSection.life) {
                NavigationStack {
                    LifeView(
                        scrollToTopSignal: lifeScrollToTopSignal,
                        refreshSignal: refreshSignal
                    )
                }
                .environment(\.wavePreset, .life)
                .environment(\.waveColor, selectedTheme.tabLifeColor)
            } label: {
                Label { Text(verbatim: AppSection.life.title) } icon: { Image(systemName: AppSection.life.icon) }
            }
        }
        .environment(\.appTheme, selectedTheme)
        .tint(selectedTheme.accentColor)
        .tabViewStyle(.sidebarAdaptable)
        // Foreground refresh: scenePhase .background → .active (Correction #16/#60)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background, newPhase == .active {
                foregroundTask?.cancel()
                foregroundTask = Task {
                    _ = await refreshCoordinator?.requestRefresh(source: .foreground)
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
                    case .life:
                        lifeScrollToTopSignal += 1
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
