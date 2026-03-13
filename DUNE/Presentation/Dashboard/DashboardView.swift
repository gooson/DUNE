import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @State private var isShowingPinnedEditor = false
    @State private var isShowingHealthDataQA = false
    @State private var hasAppeared = false
    @State private var unreadNotificationCount = 0
    @State private var showWhatsNewBadge = false
    @State private var cachedWhatsNewReleases: [WhatsNewReleaseData] = []
    @State private var cachedCurrentRelease: WhatsNewReleaseData?
    @State private var cachedBuildNumber: String = ""
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openURL) private var openURL
    private let inboxManager = NotificationInboxManager.shared
    private let whatsNewStore = WhatsNewStore.shared
    private let whatsNewManager = WhatsNewManager.shared
    private let scrollToTopSignal: Int

    private enum ScrollAnchor: Hashable {
        case top
    }

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    private let refreshSignal: Int
    private let notificationHubSignal: Int
    private let launchExperienceReady: Bool
    private let canLoadHealthKitData: Bool
    private let sharedHealthDataService: SharedHealthDataService?
    private let scoreRefreshService: ScoreRefreshService?
    @State private var showNotificationHub = false
    @State private var showWhatsNew = false
    @State private var showSettings = false
    @State private var heroFrame: CGRect?

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        scoreRefreshService: ScoreRefreshService? = nil,
        scrollToTopSignal: Int = 0,
        refreshSignal: Int = 0,
        notificationHubSignal: Int = 0,
        launchExperienceReady: Bool = true,
        canLoadHealthKitData: Bool = true
    ) {
        self.sharedHealthDataService = sharedHealthDataService
        self.scoreRefreshService = scoreRefreshService
        _viewModel = State(initialValue: DashboardViewModel(
            sharedHealthDataService: sharedHealthDataService,
            scoreRefreshService: scoreRefreshService
        ))
        self.scrollToTopSignal = scrollToTopSignal
        self.refreshSignal = refreshSignal
        self.notificationHubSignal = notificationHubSignal
        self.launchExperienceReady = launchExperienceReady
        self.canLoadHealthKitData = canLoadHealthKitData
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(ScrollAnchor.top)

                VStack(spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                    if !launchExperienceReady {
                        DashboardSkeletonView()
                    } else if viewModel.isLoading && !hasAppeared {
                        DashboardSkeletonView()
                    } else if viewModel.sortedMetrics.isEmpty && !viewModel.isLoading {
                        if viewModel.errorMessage != nil {
                            errorSection
                        } else if viewModel.isMirroredReadOnlyMode {
                            CloudSyncWaitingView()
                        } else {
                            EmptyStateView(
                                icon: "heart.text.clipboard",
                                title: "No Health Data",
                                message: "Grant HealthKit access to see your daily metrics.",
                                actionTitle: "Open Settings",
                                action: openSettings
                            )
                        }
                    } else {
                        // Hero
                        if let score = viewModel.conditionScore {
                            NavigationLink(value: score) {
                                ConditionHeroView(
                                    score: score,
                                    recentScores: viewModel.recentScores,
                                    weeklyGoalProgress: viewModel.weeklyGoalProgress,
                                    trendBadges: viewModel.heroBaselineDetails,
                                    hourlySparkline: viewModel.conditionSparkline.nonEmptyOrNil
                                )
                            }
                            .reportTabHeroFrame()
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dashboard-hero-condition")
                            .transition(Self.sectionTransition)
                        } else if let status = viewModel.baselineStatus, !status.isReady {
                            BaselineProgressView(status: status)
                                .reportTabHeroFrame()
                                .transition(Self.sectionTransition)
                        }

                        // Weather + coaching (merged when coaching is weather-category)
                        Group {
                            if let weather = viewModel.weatherSnapshot {
                                NavigationLink(value: weather) {
                                    WeatherCard(snapshot: weather, insightInfo: viewModel.weatherCardInsight)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("dashboard-weather-card")
                            } else {
                                WeatherCardPlaceholder {
                                    Task { await viewModel.requestLocationPermission() }
                                }
                            }
                        }
                        .transition(Self.sectionTransition)

                        // Coaching (standalone when not merged into weather card)
                        if let insight = viewModel.standaloneCoachingInsight {
                            TodayCoachingCard(insight: insight)
                                .transition(Self.sectionTransition)
                        } else if viewModel.focusInsight == nil,
                                  let coachingMessage = viewModel.coachingMessage {
                            TodayCoachingCard(message: coachingMessage)
                                .transition(Self.sectionTransition)
                        }

                        HealthDataQACard(isAvailable: HealthDataQAService.isAvailable) {
                            isShowingHealthDataQA = true
                        }

                        // Insight Cards
                        if !viewModel.insightCards.isEmpty {
                            insightCardsSection
                                .transition(Self.sectionTransition)
                        }

                        // Sleep deficit badge
                        sleepDeficitSection

                        // Pinned Metrics
                        if !viewModel.pinnedCards.isEmpty {
                            pinnedSection
                                .transition(Self.sectionTransition)
                        }

                        // Last updated + error banner
                        if let lastUpdated = viewModel.lastUpdated {
                            Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .transition(.opacity)
                        }

                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                                .transition(Self.errorBannerTransition)
                        }

                        // Condition (HRV, RHR)
                        if !viewModel.conditionCards.isEmpty {
                            cardSection(
                                title: "Condition",
                                icon: "heart.fill",
                                iconColor: DS.Color.vitals,
                                accessibilityIdentifier: "dashboard-section-condition",
                                cards: viewModel.conditionCards
                            )
                            .transition(Self.sectionTransition)
                        }

                        // Activity (Steps, Exercise)
                        if !viewModel.activityCards.isEmpty {
                            cardSection(
                                title: "Activity",
                                icon: "figure.run",
                                iconColor: DS.Color.activity,
                                accessibilityIdentifier: "dashboard-section-activity",
                                cards: viewModel.activityCards
                            )
                            .transition(Self.sectionTransition)
                        }

                        // Body (Weight, BMI, Sleep)
                        if !viewModel.bodyCards.isEmpty {
                            cardSection(
                                title: "Body",
                                icon: "bed.double.fill",
                                iconColor: DS.Color.body,
                                accessibilityIdentifier: "dashboard-section-body",
                                cards: viewModel.bodyCards
                            )
                            .transition(Self.sectionTransition)
                        }

                    }
                }
                .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
                .animation(reduceMotion ? .none : DS.Animation.standard, value: sectionVisibilityHash)
                .coordinateSpace(name: TabHeroStartLine.coordinateSpace)
            }
            .onChange(of: scrollToTopSignal) { _, _ in
                withAnimation(DS.Animation.standard) {
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
        }
        .onPreferenceChange(TabHeroFramePreferenceKey.self) { heroFrame = $0 }
        .environment(\.weatherAtmosphere, viewModel.weatherAtmosphere)
        .background {
            TabWaveBackground()
                .environment(\.tabHeroStartLineInset, heroFrame.map(TabHeroStartLine.inset(for:)))
        }
        .navigationDestination(for: ConditionScore.self) { score in
            ConditionScoreDetailView(score: score, scoreRefreshService: scoreRefreshService)
        }
        .navigationDestination(for: HealthMetric.self) { metric in
            MetricDetailView(metric: metric)
        }
        .navigationDestination(for: AllDataDestination.self) { destination in
            AllDataView(category: destination.category)
        }
        .navigationDestination(for: WeatherSnapshot.self) { snapshot in
            WeatherDetailView(snapshot: snapshot)
        }
        .waveRefreshable {
            guard launchExperienceReady else { return }
            await loadDashboard()
        }
        .task(id: dashboardLoadTrigger) {
            guard launchExperienceReady else { return }
            await loadDashboard()
        }
        .task {
            loadWhatsNewCache()
            reloadUnreadCount()
            reloadWhatsNewBadge()
        }
        .onAppear {
            reloadUnreadCount()
            reloadWhatsNewBadge()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationInboxManager.inboxDidChangeNotification)) { _ in
            reloadUnreadCount()
        }
        .sheet(isPresented: $isShowingPinnedEditor) {
            PinnedMetricsEditorView(
                selection: Binding(
                    get: { viewModel.pinnedCategories },
                    set: { viewModel.setPinnedCategories($0) }
                ),
                allowedCategories: viewModel.availablePinnedCategories
            )
        }
        .sheet(isPresented: $isShowingHealthDataQA) {
            HealthDataQASheet(
                viewModel: HealthDataQAViewModel(
                    service: HealthDataQAService(sharedHealthDataService: sharedHealthDataService),
                    isAvailable: HealthDataQAService.isAvailable
                )
            )
        }
        .englishNavigationTitle("Today")
        .toolbar {
            notificationsToolbarItem
            whatsNewToolbarItem
            settingsToolbarItem
        }
        .navigationDestination(isPresented: $showNotificationHub) {
            NotificationHubView(sharedHealthDataService: sharedHealthDataService)
        }
        .navigationDestination(isPresented: $showWhatsNew) {
            WhatsNewView(
                releases: cachedWhatsNewReleases,
                mode: .manual,
                onPresented: markWhatsNewOpened
            )
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: notificationHubSignal) { _, newValue in
            guard newValue > 0 else { return }
            showNotificationHub = true
        }
    }

    // MARK: - Transitions

    private static let sectionTransition: AnyTransition =
        .opacity.combined(with: .scale(scale: 0.95, anchor: .top))

    private static let errorBannerTransition: AnyTransition =
        .opacity.combined(with: .move(edge: .top))

    /// O(1) hash covering all section-visibility drivers.
    private var sectionVisibilityHash: Int {
        var h = Hasher()
        h.combine(viewModel.sortedMetrics.count)
        h.combine(viewModel.conditionScore != nil)
        h.combine(viewModel.baselineStatus != nil)
        h.combine(viewModel.weatherSnapshot != nil)
        h.combine(viewModel.errorMessage != nil)
        h.combine(viewModel.insightCards.count)
        h.combine(viewModel.pinnedCards.count)
        return h.finalize()
    }

    // MARK: - Sections

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "pin.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tint)

                Text("Pinned")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Color.textSecondary)

                Spacer()

                Button {
                    isShowingPinnedEditor = true
                } label: {
                    Text("Edit")
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("dashboard-pinned-edit")
                }
            }
            .padding(.horizontal, DS.Spacing.xs)

            cardGrid(cards: viewModel.pinnedCards)
                .accessibilityIdentifier("dashboard-pinned-grid")
        }
    }

    private var dashboardLoadTrigger: String {
        launchExperienceReady ? "\(refreshSignal)-\(canLoadHealthKitData)" : "blocked"
    }

    private func loadDashboard() async {
        await viewModel.loadData(canLoadHealthKitData: canLoadHealthKitData)
        guard !viewModel.isLoading else { return }
        if !hasAppeared {
            withAnimation(.easeOut(duration: 0.3)) {
                hasAppeared = true
            }
        }
        reloadUnreadCount()
        reloadWhatsNewBadge()
    }

    @ViewBuilder
    private var sleepDeficitSection: some View {
        if let deficit = viewModel.sleepDeficitAnalysis,
           deficit.level != .insufficient,
           let sleepMetric = viewModel.sortedMetrics.first(where: { $0.category == .sleep }) {
            NavigationLink(value: sleepMetric) {
                SleepDeficitBadgeView(analysis: deficit)
            }
            .buttonStyle(.plain)
            .transition(Self.sectionTransition)
        }
    }

    private var notificationBellIcon: some View {
        Image(systemName: "bell")
            .frame(width: 22, height: 22)
            .overlay(alignment: .topTrailing) {
                if unreadNotificationCount > 0 {
                    Text(unreadBadgeLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.red, in: Capsule())
                        .offset(x: 6)
                        .accessibilityLabel("\(unreadNotificationCount.formatted()) unread notifications")
                }
            }
    }

    private var unreadBadgeLabel: String {
        unreadNotificationCount > 99 ? "99+" : unreadNotificationCount.formatted()
    }

    private func reloadUnreadCount() {
        unreadNotificationCount = inboxManager.unreadCount()
    }

    private func loadWhatsNewCache() {
        let version = whatsNewManager.currentAppVersion()
        cachedWhatsNewReleases = whatsNewManager.orderedReleases(preferredVersion: version)
        cachedCurrentRelease = version.isEmpty ? nil : whatsNewManager.currentRelease(for: version)
        cachedBuildNumber = whatsNewManager.currentBuildNumber()
    }

    @ToolbarContentBuilder
    private var notificationsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showNotificationHub = true
            } label: {
                notificationBellIcon
            }
            .accessibilityLabel("Notifications")
            .accessibilityIdentifier("dashboard-toolbar-notifications")
        }
    }

    @ToolbarContentBuilder
    private var whatsNewToolbarItem: some ToolbarContent {
        if !cachedWhatsNewReleases.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showWhatsNew = true
                } label: {
                    whatsNewToolbarIcon
                }
                .accessibilityLabel("What's New")
                .accessibilityIdentifier("dashboard-toolbar-whatsnew")
            }
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("dashboard-toolbar-settings")
        }
    }

    private var whatsNewToolbarIcon: some View {
        Image(systemName: "sparkles")
            .frame(width: 22, height: 22)
            .overlay(alignment: .topTrailing) {
                if showWhatsNewBadge {
                    Circle()
                        .fill(DS.Color.activity)
                        .frame(width: 9, height: 9)
                        .overlay {
                            Circle()
                                .stroke(Color(uiColor: .systemBackground), lineWidth: 1.5)
                        }
                        .offset(x: 4, y: -1)
                }
            }
    }

    private func reloadWhatsNewBadge() {
        guard cachedCurrentRelease != nil else {
            showWhatsNewBadge = false
            return
        }

        showWhatsNewBadge = whatsNewStore.shouldShowBadge(build: cachedBuildNumber)
    }

    private func markWhatsNewOpened() {
        guard !cachedBuildNumber.isEmpty else { return }
        whatsNewStore.markOpened(build: cachedBuildNumber)
        showWhatsNewBadge = false
    }

    private var insightCardsSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(viewModel.insightCards) { card in
                InsightCardView(data: card) {
                    withAnimation(DS.Animation.standard) {
                        viewModel.dismissInsightCard(id: card.id)
                    }
                }
            }
        }
    }

    private func cardSection(
        title: LocalizedStringKey,
        icon: String,
        iconColor: Color,
        accessibilityIdentifier: String,
        cards: [VitalCardData]
    ) -> some View {
        SectionGroup(title: title, icon: icon, iconColor: iconColor) {
            cardGrid(cards: cards)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func cardGrid(cards: [VitalCardData]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: DS.Spacing.md) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                NavigationLink(value: card.metric) {
                    VitalCard(data: card, animationIndex: index)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .accessibilityIdentifier(metricCardIdentifier(for: card.metric.category))
                .contextMenu {
                    NavigationLink(value: card.metric) {
                        Label("View Trend", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink(value: AllDataDestination(category: card.category)) {
                        Label("Show All Data", systemImage: "list.bullet")
                    }
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 8)
                .animation(
                    reduceMotion
                        ? .none
                        : .easeOut(duration: 0.35).delay(Double(min(index, 5)) * 0.05),
                    value: hasAppeared
                )
            }
        }
    }

    // MARK: - Error States

    private var errorSection: some View {
        let message: LocalizedStringKey = if let msg = viewModel.errorMessage {
            "\(msg)"
        } else {
            "An unexpected error occurred."
        }
        return EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Something Went Wrong",
            message: message,
            actionTitle: "Try Again",
            action: { Task { await viewModel.loadData() } }
        )
    }

    private func errorBanner(_ message: String) -> some View {
        InlineCard {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Color.caution)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineLimit(2)

                Spacer()

                Button("Retry") {
                    Task { await viewModel.loadData() }
                }
                .font(.caption)
                .fontWeight(.medium)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func metricCardIdentifier(for category: HealthMetric.Category) -> String {
        "dashboard-metric-\(category.rawValue)"
    }
}

// MARK: - Baseline Progress

private struct BaselineProgressView: View {
    let status: BaselineStatus

    private var progressText: String {
        String(
            format: String(localized: "%@/%@ days"),
            locale: Locale.current,
            status.daysCollected.formattedWithSeparator,
            status.daysRequired.formattedWithSeparator
        )
    }

    var body: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.md) {
                Text("Establishing Baseline")
                    .font(.headline)

                ProgressView(value: status.progress)
                    .tint(DS.Color.hrv)

                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }
}

#Preview {
    DashboardView()
}
