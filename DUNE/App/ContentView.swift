import SwiftUI

enum NotificationPresentationDestination: Hashable {
    case personalRecords(requestID: Int)
}

enum NotificationPresentationPlan: Equatable {
    case push(NotificationPresentationDestination)
    case openWorkoutInActivity(workoutID: String)
    case openNotificationHub
}

enum NotificationPresentationPlanner {
    static func plan(for route: NotificationRoute, requestID: Int) -> NotificationPresentationPlan? {
        switch route.destination {
        case .workoutDetail:
            guard let workoutID = route.workoutID, !workoutID.isEmpty else { return nil }
            return .openWorkoutInActivity(workoutID: workoutID)
        case .activityPersonalRecords:
            return .push(.personalRecords(requestID: requestID))
        case .notificationHub:
            return .openNotificationHub
        }
    }

    static func rootPath(for plan: NotificationPresentationPlan) -> [NotificationPresentationDestination] {
        switch plan {
        case .push(let destination):
            [destination]
        case .openWorkoutInActivity, .openNotificationHub:
            []
        }
    }
}

struct ContentView: View {
    private let sharedHealthDataService: SharedHealthDataService?
    private let refreshCoordinator: AppRefreshCoordinating?
    private let launchExperienceReady: Bool
    private let shouldAutoRequestHealthKitAuthorization: Bool
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @State private var selectedSection: AppSection
    @State private var todayScrollToTopSignal = 0
    @State private var activityScrollToTopSignal = 0
    @State private var wellnessScrollToTopSignal = 0
    @State private var lifeScrollToTopSignal = 0
    @State private var refreshSignal = 0
    @State private var foregroundTask: Task<Void, Never>?
    @State private var notificationOpenWorkoutID: String?
    @State private var notificationPresentationPath: [NotificationPresentationDestination] = []
    @State private var notificationPresentationRequestID = 0
    @State private var notificationRouteSignal = 0
    @State private var notificationHubSignal = 0
    private let notificationInboxManager = NotificationInboxManager.shared

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        refreshCoordinator: AppRefreshCoordinating? = nil,
        launchExperienceReady: Bool = true,
        shouldAutoRequestHealthKitAuthorization: Bool = true
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.refreshCoordinator = refreshCoordinator
        self.launchExperienceReady = launchExperienceReady
        self.shouldAutoRequestHealthKitAuthorization = shouldAutoRequestHealthKitAuthorization
        _selectedSection = State(initialValue: Self.initialSectionForUITests())
    }

    var body: some View {
        NavigationStack(path: $notificationPresentationPath) {
            TabView(selection: tabSelection) {
                Tab(value: AppSection.today) {
                    NavigationStack {
                        DashboardView(
                            sharedHealthDataService: sharedHealthDataService,
                            scrollToTopSignal: todayScrollToTopSignal,
                            refreshSignal: refreshSignal,
                            notificationHubSignal: notificationHubSignal,
                            launchExperienceReady: launchExperienceReady,
                            shouldAutoRequestHealthKitAuthorization: shouldAutoRequestHealthKitAuthorization
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
                            notificationRouteSignal: notificationRouteSignal
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
                            refreshSignal: refreshSignal
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
            .navigationDestination(for: NotificationPresentationDestination.self) { destination in
                switch destination {
                case .personalRecords:
                    NotificationPersonalRecordsPushView(
                        sharedHealthDataService: sharedHealthDataService
                    )
                }
            }
            // Foreground refresh: scenePhase .background → .active (Correction #16/#60)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    notificationInboxManager.syncBadge()
                    Task {
                        await BedtimeWatchReminderScheduler.shared.refreshSchedule()
                    }
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
        }
    }

    private static func initialSectionForUITests() -> AppSection {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--uitesting"),
              let index = args.firstIndex(of: "--uitest-initial-tab"),
              args.indices.contains(index + 1) else {
            return .today
        }

        return AppSection(rawValue: args[index + 1]) ?? .today
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
        notificationPresentationRequestID += 1

        guard let plan = NotificationPresentationPlanner.plan(
            for: request.route,
            requestID: notificationPresentationRequestID
        ) else {
            return
        }

        notificationPresentationPath = NotificationPresentationPlanner.rootPath(for: plan)

        switch plan {
        case .push:
            break
        case .openWorkoutInActivity(let workoutID):
            selectedSection = .train
            notificationOpenWorkoutID = workoutID
            notificationRouteSignal += 1
        case .openNotificationHub:
            selectedSection = .today
            notificationHubSignal += 1
        }
    }
}

private struct NotificationPersonalRecordsPushView: View {
    @State private var viewModel: ActivityViewModel

    init(sharedHealthDataService: SharedHealthDataService?) {
        _viewModel = State(initialValue: ActivityViewModel(sharedHealthDataService: sharedHealthDataService))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.personalRecords.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background { DetailWaveBackground() }
                    .englishNavigationTitle("Personal Records")
            } else {
                PersonalRecordsDetailView(
                    records: viewModel.personalRecords,
                    notice: viewModel.personalRecordNotice,
                    rewardSummary: viewModel.workoutRewardSummary,
                    rewardHistory: viewModel.workoutRewardHistory
                )
            }
        }
        .task {
            await viewModel.loadActivityData()
        }
    }
}

#Preview {
    ContentView()
}
