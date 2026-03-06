import SwiftUI

struct ContentView: View {
    private let sharedHealthDataService: SharedHealthDataService?
    private let refreshCoordinator: AppRefreshCoordinating?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @State private var selectedSection: AppSection = .today
    @State private var todayScrollToTopSignal = 0
    @State private var activityScrollToTopSignal = 0
    @State private var wellnessScrollToTopSignal = 0
    @State private var lifeScrollToTopSignal = 0
    @State private var refreshSignal = 0
    @State private var foregroundTask: Task<Void, Never>?
    @State private var notificationOpenWorkoutID: String?
    @State private var notificationRouteSignal = 0
    @State private var notificationPersonalRecordsSignal = 0
    @State private var notificationHubSignal = 0
    @State private var whatsNewConditionSignal = 0
    @State private var whatsNewTrainingReadinessSignal = 0
    @State private var whatsNewWellnessScoreSignal = 0
    private let notificationInboxManager = NotificationInboxManager.shared
    private let whatsNewManager = WhatsNewManager.shared

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
                        refreshSignal: refreshSignal,
                        notificationHubSignal: notificationHubSignal,
                        whatsNewConditionSignal: whatsNewConditionSignal
                    )
                }
                .environment(\.wavePreset, .today)
                .environment(\.waveColor, selectedTheme.tabTodayColor)
            } label: {
                Label { Text(verbatim: AppSection.today.title) } icon: { Image(systemName: AppSection.today.icon) }
                    .accessibilityIdentifier("tab-today")
            }
            Tab(value: AppSection.train) {
                NavigationStack {
                    ActivityView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: activityScrollToTopSignal,
                        refreshSignal: refreshSignal,
                        notificationWorkoutID: notificationOpenWorkoutID,
                        notificationRouteSignal: notificationRouteSignal,
                        notificationPersonalRecordsSignal: notificationPersonalRecordsSignal,
                        whatsNewTrainingReadinessSignal: whatsNewTrainingReadinessSignal
                    )
                }
                .environment(\.wavePreset, .train)
                .environment(\.waveColor, selectedTheme.tabTrainColor)
            } label: {
                Label { Text(verbatim: AppSection.train.title) } icon: { Image(systemName: AppSection.train.icon) }
                    .accessibilityIdentifier("tab-activity")
            }
            Tab(value: AppSection.wellness) {
                NavigationStack {
                    WellnessView(
                        sharedHealthDataService: sharedHealthDataService,
                        scrollToTopSignal: wellnessScrollToTopSignal,
                        refreshSignal: refreshSignal,
                        whatsNewWellnessScoreSignal: whatsNewWellnessScoreSignal
                    )
                }
                .environment(\.wavePreset, .wellness)
                .environment(\.waveColor, selectedTheme.tabWellnessColor)
            } label: {
                Label { Text(verbatim: AppSection.wellness.title) } icon: { Image(systemName: AppSection.wellness.icon) }
                    .accessibilityIdentifier("tab-wellness")
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
                    .accessibilityIdentifier("tab-life")
            }
        }
        .environment(\.appTheme, selectedTheme)
        .tint(selectedTheme.accentColor)
        .tabViewStyle(.sidebarAdaptable)
        // Foreground refresh: scenePhase .background → .active (Correction #16/#60)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                notificationInboxManager.syncBadge()
            }
            if oldPhase == .background, newPhase == .active {
                foregroundTask?.cancel()
                foregroundTask = Task {
                    _ = await refreshCoordinator?.requestRefresh(source: .foreground)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationInboxManager.routeRequestedNotification)) { notification in
            guard let request = NotificationInboxManager.navigationRequest(from: notification) else { return }
            handleNotificationNavigationRequest(request)
            notificationInboxManager.clearPendingNavigationRequest(ifMatching: request)
        }
        .onReceive(NotificationCenter.default.publisher(for: WhatsNewManager.routeRequestedNotification)) { notification in
            guard let destination = WhatsNewManager.destination(from: notification) else { return }
            handleWhatsNewNavigationRequest(destination)
            whatsNewManager.clearPendingNavigationDestination(ifMatching: destination)
        }
        // Listen for refresh signals from coordinator (foreground + HK observer triggers)
        .task {
            guard let coordinator = refreshCoordinator else { return }
            for await _ in coordinator.refreshNeededStream {
                refreshSignal += 1
            }
        }
        .task {
            if let request = notificationInboxManager.consumePendingNavigationRequest() {
                handleNotificationNavigationRequest(request)
            }
        }
        .task {
            if let destination = whatsNewManager.consumePendingNavigationDestination() {
                handleWhatsNewNavigationRequest(destination)
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

    private func handleNotificationNavigationRequest(_ request: NotificationNavigationRequest) {
        switch request.route.destination {
        case .workoutDetail:
            guard let workoutID = request.route.workoutID, !workoutID.isEmpty else { return }
            selectedSection = .train
            notificationOpenWorkoutID = workoutID
            notificationRouteSignal += 1
        case .activityPersonalRecords:
            selectedSection = .train
            notificationPersonalRecordsSignal += 1
        case .notificationHub:
            selectedSection = .today
            notificationHubSignal += 1
        }
    }

    private func handleWhatsNewNavigationRequest(_ destination: WhatsNewDestination) {
        switch destination {
        case .conditionScore:
            selectedSection = .today
            whatsNewConditionSignal += 1
        case .notificationHub:
            selectedSection = .today
            notificationHubSignal += 1
        case .trainingReadiness:
            selectedSection = .train
            whatsNewTrainingReadinessSignal += 1
        case .wellnessScore:
            selectedSection = .wellness
            whatsNewWellnessScoreSignal += 1
        case .activityOverview:
            selectedSection = .train
        case .lifeOverview:
            selectedSection = .life
        }
    }
}

#Preview {
    ContentView()
}
