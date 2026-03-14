import SwiftUI

enum NotificationPresentationDestination: Hashable {
    case personalRecords(requestID: Int)
    case sleepDetail(requestID: Int)
}

enum NotificationPresentationPlan: Equatable {
    case push(NotificationPresentationDestination)
    case openWorkoutInActivity(workoutID: String)
    case openNotificationHub
    case openSleepDetailInWellness(requestID: Int)
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
        case .sleepDetail:
            return .openSleepDetailInWellness(requestID: requestID)
        }
    }

    static func rootPath(for plan: NotificationPresentationPlan) -> [NotificationPresentationDestination] {
        switch plan {
        case .push(let destination):
            [destination]
        case .openWorkoutInActivity, .openNotificationHub, .openSleepDetailInWellness:
            []
        }
    }
}

// Pure path policy helper shared with tests. NavigationStack still binds directly
// to the tab-scoped @State NavigationPath values below.
struct NotificationPresentationPaths {
    var today = NavigationPath()
    var train = NavigationPath()
    var wellness = NavigationPath()
    var life = NavigationPath()

    mutating func setPath(_ destinations: [NotificationPresentationDestination], for section: AppSection) {
        clearAll(except: section)
        updatePath(makePath(from: destinations), for: section)
    }

    mutating func updatePath(_ path: NavigationPath, for section: AppSection) {
        switch section {
        case .today:
            today = path
        case .train:
            train = path
        case .wellness:
            wellness = path
        case .life:
            life = path
        }
    }

    mutating func clearAll(except excluded: AppSection? = nil) {
        if excluded != .today && !today.isEmpty { today = NavigationPath() }
        if excluded != .train && !train.isEmpty { train = NavigationPath() }
        if excluded != .wellness && !wellness.isEmpty { wellness = NavigationPath() }
        if excluded != .life && !life.isEmpty { life = NavigationPath() }
    }

    private func makePath(from destinations: [NotificationPresentationDestination]) -> NavigationPath {
        var path = NavigationPath()
        for destination in destinations {
            path.append(destination)
        }
        return path
    }
}

struct NotificationPresentationState {
    var selectedSection: AppSection
    var notificationOpenWorkoutID: String?
    var paths: NotificationPresentationPaths
    var notificationPresentationRequestID: Int
    var notificationRouteSignal: Int
    var notificationHubSignal: Int

    mutating func apply(_ request: NotificationNavigationRequest) {
        notificationPresentationRequestID += 1

        guard let plan = NotificationPresentationPlanner.plan(
            for: request.route,
            requestID: notificationPresentationRequestID
        ) else {
            return
        }

        switch plan {
        case .push:
            paths.clearAll(except: selectedSection)
            let destinations = NotificationPresentationPlanner.rootPath(for: plan)
            paths.setPath(destinations, for: selectedSection)
        case .openWorkoutInActivity(let workoutID):
            paths.clearAll()
            selectedSection = .train
            notificationOpenWorkoutID = workoutID
            notificationRouteSignal += 1
        case .openNotificationHub:
            paths.clearAll()
            selectedSection = .today
            notificationHubSignal += 1
        case .openSleepDetailInWellness(let requestID):
            paths.clearAll(except: .wellness)
            selectedSection = .wellness
            paths.setPath([.sleepDetail(requestID: requestID)], for: .wellness)
        }
    }
}

struct ContentView: View {
    private let sharedHealthDataService: SharedHealthDataService?
    private let refreshCoordinator: AppRefreshCoordinating?
    private let scoreRefreshService: ScoreRefreshService?
    private let launchExperienceReady: Bool
    private let canLoadHealthKitData: Bool
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
    @State private var todayNavPath = NavigationPath()
    @State private var trainNavPath = NavigationPath()
    @State private var wellnessNavPath = NavigationPath()
    @State private var lifeNavPath = NavigationPath()
    @State private var notificationPresentationRequestID = 0
    @State private var notificationRouteSignal = 0
    @State private var notificationHubSignal = 0
    private let notificationInboxManager = NotificationInboxManager.shared

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        refreshCoordinator: AppRefreshCoordinating? = nil,
        scoreRefreshService: ScoreRefreshService? = nil,
        launchExperienceReady: Bool = true,
        canLoadHealthKitData: Bool = true
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.refreshCoordinator = refreshCoordinator
        self.scoreRefreshService = scoreRefreshService
        self.launchExperienceReady = launchExperienceReady
        self.canLoadHealthKitData = canLoadHealthKitData
        _selectedSection = State(initialValue: Self.initialSectionForUITests())
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab(value: AppSection.today) {
                NavigationStack(path: $todayNavPath) {
                    DashboardView(
                        sharedHealthDataService: sharedHealthDataService,
                        scoreRefreshService: scoreRefreshService,
                        scrollToTopSignal: todayScrollToTopSignal,
                        refreshSignal: refreshSignal,
                        notificationHubSignal: notificationHubSignal,
                        launchExperienceReady: launchExperienceReady,
                        canLoadHealthKitData: canLoadHealthKitData
                    )
                    .navigationDestination(for: NotificationPresentationDestination.self) { destination in
                        notificationDestinationView(for: destination)
                    }
                }
                .environment(\.wavePreset, .today)
                .environment(\.waveColor, selectedTheme.tabTodayColor)
            } label: {
                Label { Text(verbatim: AppSection.today.title) } icon: { Image(systemName: AppSection.today.icon) }
                    .accessibilityIdentifier("tab-today")
            }
            Tab(value: AppSection.train) {
                NavigationStack(path: $trainNavPath) {
                    ActivityView(
                        sharedHealthDataService: sharedHealthDataService,
                        scoreRefreshService: scoreRefreshService,
                        scrollToTopSignal: activityScrollToTopSignal,
                        refreshSignal: refreshSignal,
                        notificationWorkoutID: notificationOpenWorkoutID,
                        notificationRouteSignal: notificationRouteSignal
                    )
                    .navigationDestination(for: NotificationPresentationDestination.self) { destination in
                        notificationDestinationView(for: destination)
                    }
                }
                .environment(\.wavePreset, .train)
                .environment(\.waveColor, selectedTheme.tabTrainColor)
            } label: {
                Label { Text(verbatim: AppSection.train.title) } icon: { Image(systemName: AppSection.train.icon) }
                    .accessibilityIdentifier("tab-activity")
            }
            Tab(value: AppSection.wellness) {
                NavigationStack(path: $wellnessNavPath) {
                    WellnessView(
                        sharedHealthDataService: sharedHealthDataService,
                        scoreRefreshService: scoreRefreshService,
                        scrollToTopSignal: wellnessScrollToTopSignal,
                        refreshSignal: refreshSignal
                    )
                    .navigationDestination(for: NotificationPresentationDestination.self) { destination in
                        notificationDestinationView(for: destination)
                    }
                }
                .environment(\.wavePreset, .wellness)
                .environment(\.waveColor, selectedTheme.tabWellnessColor)
            } label: {
                Label { Text(verbatim: AppSection.wellness.title) } icon: { Image(systemName: AppSection.wellness.icon) }
                    .accessibilityIdentifier("tab-wellness")
            }
            Tab(value: AppSection.life) {
                NavigationStack(path: $lifeNavPath) {
                    LifeView(
                        scrollToTopSignal: lifeScrollToTopSignal,
                        refreshSignal: refreshSignal
                    )
                    .navigationDestination(for: NotificationPresentationDestination.self) { destination in
                        notificationDestinationView(for: destination)
                    }
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
                // Fallback: consume any pending navigation request that .onReceive may have missed
                // (e.g. notification posted before the Combine subscription was active).
                // If .onReceive already consumed it, this returns nil harmlessly (dedup via consume).
                if let request = notificationInboxManager.consumePendingNavigationRequest() {
                    AppLogger.notification.info("[ContentView] scenePhase fallback navigation: route=\(request.route.destination.rawValue)")
                    MainActor.assumeIsolated {
                        handleNotificationNavigationRequest(request)
                    }
                }
                Task {
                    await BedtimeReminderScheduler.shared.refreshSchedule()
                }
            }
            if oldPhase == .background, newPhase == .active {
                foregroundTask?.cancel()
                foregroundTask = Task {
                    _ = await refreshCoordinator?.requestRefresh(source: .foreground)
                }
            }
        }
        .onReceive(NotificationCenter.default.mainThreadPublisher(for: NotificationInboxManager.routeRequestedNotification)) { notification in
            guard let request = NotificationInboxManager.navigationRequest(from: notification) else { return }
            guard notificationInboxManager.consumePendingNavigationRequest(ifMatching: request) else { return }
            MainActor.assumeIsolated {
                handleNotificationNavigationRequest(request)
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
            }
        }
        // Listen for refresh signals from coordinator (foreground + HK observer triggers)
        .task {
            guard let coordinator = refreshCoordinator else { return }
            for await _ in coordinator.refreshNeededStream {
                await MainActor.run {
                    refreshSignal += 1
                }
            }
        }
        .task(id: launchExperienceReady) {
            guard launchExperienceReady else { return }
            // Yield once so NavigationStack destinations are registered before pushing.
            await Task.yield()
            if let request = notificationInboxManager.consumePendingNavigationRequest() {
                AppLogger.notification.info("[ContentView] Cold-start pending navigation: route=\(request.route.destination.rawValue)")
                // SwiftUI's .task(id:) action is nonisolated; after the first suspension
                // we must re-enter MainActor before mutating tab and navigation state.
                await MainActor.run {
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

    @ViewBuilder
    private func notificationDestinationView(for destination: NotificationPresentationDestination) -> some View {
        switch destination {
        case .personalRecords:
            NotificationPersonalRecordsPushView(
                sharedHealthDataService: sharedHealthDataService
            )
        case .sleepDetail:
            NotificationSleepDetailPushView(sharedHealthDataService: sharedHealthDataService)
        }
    }

    private var currentNotificationPresentationPaths: NotificationPresentationPaths {
        NotificationPresentationPaths(
            today: todayNavPath,
            train: trainNavPath,
            wellness: wellnessNavPath,
            life: lifeNavPath
        )
    }

    private var currentNotificationPresentationState: NotificationPresentationState {
        NotificationPresentationState(
            selectedSection: selectedSection,
            notificationOpenWorkoutID: notificationOpenWorkoutID,
            paths: currentNotificationPresentationPaths,
            notificationPresentationRequestID: notificationPresentationRequestID,
            notificationRouteSignal: notificationRouteSignal,
            notificationHubSignal: notificationHubSignal
        )
    }

    @MainActor
    private func applyNotificationPresentationState(_ state: NotificationPresentationState) {
        selectedSection = state.selectedSection
        notificationOpenWorkoutID = state.notificationOpenWorkoutID
        todayNavPath = state.paths.today
        trainNavPath = state.paths.train
        wellnessNavPath = state.paths.wellness
        lifeNavPath = state.paths.life
        notificationPresentationRequestID = state.notificationPresentationRequestID
        notificationRouteSignal = state.notificationRouteSignal
        notificationHubSignal = state.notificationHubSignal
    }

    @MainActor
    private func handleNotificationNavigationRequest(_ request: NotificationNavigationRequest) {
        var state = currentNotificationPresentationState
        state.apply(request)
        applyNotificationPresentationState(state)
    }
}

private struct NotificationSleepDetailPushView: View {
    @State private var viewModel: WellnessViewModel

    init(sharedHealthDataService: SharedHealthDataService?) {
        _viewModel = State(initialValue: WellnessViewModel(sharedHealthDataService: sharedHealthDataService))
    }

    var body: some View {
        Group {
            if let prediction = viewModel.sleepPrediction {
                SleepPredictionDetailView(prediction: prediction)
            } else if viewModel.isLoading {
                ProgressView()
            } else {
                EmptyStateView(
                    icon: "moon.zzz",
                    title: "Sleep Detail Unavailable",
                    message: "Open Wellness to refresh your latest sleep data."
                )
            }
        }
        .task {
            viewModel.loadData()
        }
    }
}

#Preview {
    ContentView()
}
