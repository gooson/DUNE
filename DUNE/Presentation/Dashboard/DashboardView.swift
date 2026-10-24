import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @State private var isShowingPinnedEditor = false
    @State private var isShowingHealthDataQA = false
    @State private var inspectedMetric: HealthMetric?
    @State private var templateNudgeToSave: WorkoutTemplateRecommendation?
    @State private var hasAppeared = false
    @State private var isShowingBriefing = false
    @AppStorage("morningBriefingDisabled") private var isBriefingDisabled = false
    @State private var unreadNotificationCount = 0
    @State private var hasUnreadRelease = false
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @Query(
        {
            var fd = FetchDescriptor<ExerciseRecord>(
                sortBy: [SortDescriptor(\ExerciseRecord.date, order: .reverse)]
            )
            fd.fetchLimit = 20
            return fd
        }()
    ) private var exerciseRecords: [ExerciseRecord]
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme
    @Environment(\.openURL) private var openURL
    private let library: ExerciseLibraryQuerying = ExerciseLibraryService.shared
    private let inboxManager = NotificationInboxManager.shared
    private let scrollToTopSignal: Int

    private enum ScrollAnchor: Hashable {
        case top
    }

    private let refreshSignal: Int
    private let notificationHubSignal: Int
    private let notificationHubIsActive: Bool
    private let onOpenNotifications: () -> Void
    private let onOpenActivity: () -> Void
    private let onOpenWellness: () -> Void
    private let onLogWeight: () -> Void
    private let launchExperienceReady: Bool
    private let canLoadHealthKitData: Bool
    private let hasFailedHealthKitAuthorization: Bool
    private let sharedHealthDataService: SharedHealthDataService?
    private let scoreRefreshService: ScoreRefreshService?
    @State private var showSettings = false
    @State private var cachedWeatherAtmosphere: WeatherAtmosphere = .default
    // Coaching properties are mutated asynchronously by enhanceCoachingTask.
    // Caching in @State breaks the observation tracking during NavigationStack layout,
    // preventing feedback loops. (4th instance — see docs/solutions/performance/2026-03-29)
    @State private var cachedFocusInsight: CoachingInsight?
    @State private var cachedCoachingMessage: String?
    @State private var cachedWeatherSnapshot: WeatherSnapshot?
    @State private var cachedWeatherCardInsight: WeatherCard.InsightInfo?

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        scoreRefreshService: ScoreRefreshService? = nil,
        scrollToTopSignal: Int = 0,
        refreshSignal: Int = 0,
        notificationHubSignal: Int = 0,
        notificationHubIsActive: Bool = false,
        onOpenNotifications: @escaping () -> Void = {},
        onOpenActivity: @escaping () -> Void = {},
        onOpenWellness: @escaping () -> Void = {},
        onLogWeight: @escaping () -> Void = {},
        launchExperienceReady: Bool = true,
        canLoadHealthKitData: Bool = true,
        hasFailedHealthKitAuthorization: Bool = false
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
        self.notificationHubIsActive = notificationHubIsActive
        self.onOpenNotifications = onOpenNotifications
        self.onOpenActivity = onOpenActivity
        self.onOpenWellness = onOpenWellness
        self.onLogWeight = onLogWeight
        self.launchExperienceReady = launchExperienceReady
        self.canLoadHealthKitData = canLoadHealthKitData
        self.hasFailedHealthKitAuthorization = hasFailedHealthKitAuthorization
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(width: 0, height: 0)
                    .id(ScrollAnchor.top)

                VStack(spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                    if !launchExperienceReady {
                        DashboardSkeletonView()
                    } else if viewModel.shouldShowSkeleton(
                        canLoadHealthKitData: canLoadHealthKitData,
                        hasFailedHealthKitAuthorization: hasFailedHealthKitAuthorization
                    ) {
                        DashboardSkeletonView()
                    } else if viewModel.sortedMetrics.isEmpty && !viewModel.isLoading {
                        if viewModel.errorMessage != nil {
                            errorSection
                        } else if viewModel.isMirroredReadOnlyMode {
                            CloudSyncWaitingView {
                                Task { await viewModel.loadData(canLoadHealthKitData: canLoadHealthKitData) }
                            }
                        } else {
                            if hasFailedHealthKitAuthorization {
                                EmptyStateView(
                                    icon: "heart.text.clipboard",
                                    title: "Health Access Needed",
                                    message: "Allow Health access in Settings to see your daily metrics.",
                                    actionTitle: "Open Settings",
                                    action: openSettings
                                )
                            } else {
                                EmptyStateView(
                                    icon: "heart.text.clipboard",
                                    title: "No Measurements Yet",
                                    message: "Your health trends will appear after measurements are available.",
                                    actionTitle: "View Activity",
                                    action: onOpenActivity
                                )
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("dashboard-empty-state")
                            }
                        }
                    } else {
                        dashboardUpperContent
                        dashboardLowerContent
                    }
                }
                .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
                .frame(maxWidth: sizeClass == .regular ? DS.Layout.rootContentMaxWidth : .infinity)
                .frame(maxWidth: .infinity)
                .coordinateSpace(name: TabHeroStartLine.coordinateSpace)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("dashboard-root-scroll")
            .waveRefreshable {
                guard launchExperienceReady else { return }
                await loadDashboard()
            }
            .onChange(of: scrollToTopSignal) { _, _ in
                withAnimation(DS.Animation.standard) {
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
        }
        .environment(\.weatherAtmosphere, cachedWeatherAtmosphere)
        .backgroundPreferenceValue(TabHeroFramePreferenceKey.self) { heroFrame in
            TabWaveBackground()
                .environment(\.tabHeroStartLineInset, heroFrame.map(TabHeroStartLine.inset(for:)))
        }
        .navigationDestination(for: ConditionScore.self) { score in
            ConditionScoreDetailView(score: score, scoreRefreshService: scoreRefreshService)
        }
        .navigationDestination(for: CumulativeStressScore.self) { stressScore in
            CumulativeStressDetailView(stressScore: stressScore, scoreRefreshService: scoreRefreshService)
        }
        .navigationDestination(for: HealthMetric.self) { metric in
            MetricDetailView(metric: metric)
        }
        .navigationDestination(for: AllDataDestination.self) { destination in
            AllDataView(category: destination.category)
        }
        .navigationDestination(item: $weatherDetailNavigation) { snapshot in
            WeatherDetailView(snapshot: snapshot)
        }
        .task(id: dashboardLoadTrigger) {
            guard launchExperienceReady else { return }
            await loadDashboard()
        }
        .task {
            reloadUnreadCount()
        }
        .onAppear {
            reloadUnreadCount()
        }
        .onReceive(NotificationCenter.default.mainThreadPublisher(for: NotificationInboxManager.inboxDidChangeNotification)) { _ in
            reloadUnreadCount()
        }
        .onReceive(NotificationCenter.default.mainThreadPublisher(for: WhatsNewStore.didChangeNotification)) { _ in
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
        .sheet(isPresented: $isShowingBriefing) {
            if let briefingData = viewModel.briefingData {
                MorningBriefingView(data: briefingData)
            }
        }
        .modifier(DashboardCacheSync(viewModel: viewModel, cachedWeatherAtmosphere: $cachedWeatherAtmosphere, cachedFocusInsight: $cachedFocusInsight, cachedCoachingMessage: $cachedCoachingMessage, cachedWeatherSnapshot: $cachedWeatherSnapshot, cachedWeatherCardInsight: $cachedWeatherCardInsight, isShowingBriefing: $isShowingBriefing))
        .sheet(item: $templateNudgeToSave) { nudge in
            NavigationStack {
                TemplateFormView(
                    prefillName: nudge.title,
                    prefillEntries: TemplateExerciseResolver.resolveExercises(
                        from: nudge,
                        library: library
                    )?.map { TemplateExerciseResolver.defaultEntry(for: $0) } ?? []
                )
            }
        }
        .inspector(isPresented: Binding(
            get: { inspectedMetric != nil || isShowingHealthDataQA },
            set: { isPresented in
                if !isPresented {
                    inspectedMetric = nil
                    isShowingHealthDataQA = false
                }
            }
        )) {
            if isShowingHealthDataQA {
                HealthDataQASheet(
                    viewModel: HealthDataQAViewModel(
                        service: HealthDataQAService(sharedHealthDataService: sharedHealthDataService),
                        isAvailable: HealthDataQAService.isAvailable
                    )
                )
                .inspectorColumnWidth(min: 320, ideal: 420, max: 540)
            } else if let metric = inspectedMetric {
                NavigationStack {
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Button("Done") { inspectedMetric = nil }
                                .accessibilityIdentifier("dashboard-metric-inspector-close")
                        }
                        .padding(DS.Spacing.md)
                        MetricDetailView(metric: metric)
                            .id(metric.id)
                            .navigationDestination(for: AllDataDestination.self) { destination in
                                AllDataView(category: destination.category)
                            }
                    }
                }
                .inspectorColumnWidth(min: 320, ideal: 420, max: 540)
            }
        }
        .englishNavigationTitle("Today")
        .toolbar {
            dashboardToolbarItem
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView(
                sharedHealthDataService: sharedHealthDataService,
                canLoadHealthKitData: canLoadHealthKitData,
                hasFailedHealthKitAuthorization: hasFailedHealthKitAuthorization
            )
        }
        .onChange(of: viewModel.briefingData != nil) { _, hasData in
            if hasData,
               !notificationHubIsActive,
               !isBriefingDisabled,
               MorningBriefingViewModel.shouldShowBriefing() {
                isShowingBriefing = true
            }
        }
        .onChange(of: notificationHubSignal) { _, newValue in
            guard newValue > 0 else { return }
            isShowingBriefing = false
        }
    }

    // MARK: - Transitions

    private static let sectionTransition: AnyTransition =
        .opacity.combined(with: .scale(scale: 0.95, anchor: .top))

    private static let errorBannerTransition: AnyTransition =
        .opacity.combined(with: .move(edge: .top))

    // MARK: - Dashboard Content (split for type-checker)

    @ViewBuilder
    private var dashboardUpperContent: some View {
        // Hero
        if let score = viewModel.conditionScore {
            VStack(spacing: DS.Spacing.md) {
                DesertHorizonConditionHeroView(
                    score: score,
                    trendBadges: viewModel.heroBaselineDetails,
                    hourlySparkline: viewModel.conditionSparkline.nonEmptyOrNil,
                    recentScores: viewModel.recentScores,
                    adaptiveMessage: viewModel.adaptiveHeroMessage
                )
                .reportTabHeroFrame()
                if viewModel.hasLimitedConditionHistory {
                    LimitedHealthHistoryNotice()
                }
            }
            .transition(Self.sectionTransition)
            .staggeredAppear(index: 0)
        } else if let status = viewModel.baselineStatus, !status.isReady {
            VStack(spacing: DS.Spacing.md) {
                BaselineProgressView(status: status)
                    .reportTabHeroFrame()
                if viewModel.hasLimitedConditionHistory {
                    LimitedHealthHistoryNotice()
                }
            }
            .transition(Self.sectionTransition)
            .staggeredAppear(index: 0)
        }

        // Yesterday Recap (morning only)
        if viewModel.shouldShowYesterdayRecap {
            YesterdayRecapCard(
                workoutSummary: viewModel.yesterdayWorkoutSummary,
                sleepMinutes: viewModel.yesterdaySleepMinutes,
                yesterdayScore: viewModel.yesterdayConditionScore,
                todayScore: viewModel.conditionScore?.score
            )
            .transition(Self.sectionTransition)
            .staggeredAppear(index: 1)
        }

        // Daily Progress Rings (hidden at night)
        if viewModel.shouldShowProgressRings {
        DailyProgressRingCard(
            stepsProgress: stepsProgress,
            stepsValue: stepsValueText,
            sleepProgress: sleepProgress,
            sleepValue: sleepValueText,
            habitProgress: nil,
            habitValue: nil
        )
        .transition(Self.sectionTransition)
        .staggeredAppear(index: 3)
        }

        // Today's Brief (weather + coaching + briefing entry) — morning/daytime only
        // Read from @State caches to avoid observation tracking of volatile async-mutated
        // properties (focusInsight, coachingMessage, weatherSnapshot) during layout.
        if viewModel.shouldShowTodaysBrief,
           !isBriefingDisabled || cachedWeatherSnapshot != nil || cachedFocusInsight != nil || cachedCoachingMessage != nil {
            TodayBriefCard(
                weatherSnapshot: cachedWeatherSnapshot,
                weatherInsight: cachedWeatherCardInsight,
                focusInsight: cachedFocusInsight,
                coachingMessage: cachedCoachingMessage,
                conditionStatus: viewModel.briefingData?.conditionStatus,
                onOpenBriefing: { isShowingBriefing = true },
                onOpenWeatherDetail: { weatherDetailNavigation = viewModel.weatherSnapshot },
                onRequestLocationPermission: {
                    Task { await viewModel.requestLocationPermission() }
                }
            )
            .transition(Self.sectionTransition)
            .staggeredAppear(index: 4)
        }

        // Recovery & Sleep (sleep deficit + sleep insights)
        RecoverySleepCard(
            sleepDeficit: viewModel.sleepDeficitAnalysis,
            sleepInsights: viewModel.sleepInsightCards,
            sleepMetric: viewModel.sortedMetrics.first(where: { $0.category == .sleep }),
            onDismissInsight: { id in
                withAnimation(DS.Animation.standard) {
                    viewModel.dismissInsightCard(id: id)
                }
            }
        )
        .transition(Self.sectionTransition)
        .staggeredAppear(index: 5)

        // Cumulative Stress Score (Phase 3)
        if let stressScore = viewModel.cumulativeStressScore {
            NavigationLink(value: stressScore) {
                CumulativeStressCard(stressScore: stressScore)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dashboard-stress-score")
            .transition(Self.sectionTransition)
            .staggeredAppear(index: 6)
        }

        // Exercise Intelligence Card (morning/daytime only)
        if viewModel.shouldShowExerciseIntelligence,
           let suggestion = viewModel.workoutSuggestion, !suggestion.isRestDay {
            ExerciseIntelligenceCard(
                suggestion: suggestion,
                conditionScore: viewModel.conditionScore?.score,
                sleepMinutes: viewModel.sortedMetrics.first(where: { $0.category == .sleep })?.value
            )
            .transition(Self.sectionTransition)
            .staggeredAppear(index: 6)
        }

        // Smart Insights (non-sleep insights + template nudge)
        SmartInsightsSection(
            insightCards: viewModel.nonSleepInsightCards,
            templateNudge: viewModel.templateNudgeRecommendation,
            onDismissInsight: { id in
                withAnimation(DS.Animation.standard) {
                    viewModel.dismissInsightCard(id: id)
                }
            },
            onSaveTemplate: {
                templateNudgeToSave = viewModel.templateNudgeRecommendation
            },
            onDismissNudge: {
                withAnimation(DS.Animation.standard) {
                    viewModel.dismissTemplateNudge()
                }
            }
        )
        .transition(Self.sectionTransition)
        .staggeredAppear(index: 7)

        // Daily Digest (evening/night only — Phase 3)
        if let digest = viewModel.dailyDigest, viewModel.shouldShowDailyDigest {
            DailyDigestCard(digest: digest)
                .transition(Self.sectionTransition)
                .staggeredAppear(index: 8)
        }

    }

    @ViewBuilder
    private var dashboardLowerContent: some View {
        QuickActionsRow(
            onLogWeight: onLogWeight,
            onOpenSleep: {
                if let sleepMetric = viewModel.sortedMetrics.first(where: { $0.category == .sleep }) {
                    openMetric(sleepMetric)
                } else {
                    onOpenWellness()
                }
            }
        )
        .staggeredAppear(index: 9)

        // Pinned Metrics
        if !viewModel.pinnedCards.isEmpty {
            pinnedSection
                .transition(Self.sectionTransition)
                .staggeredAppear(index: 9)
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
            .staggeredAppear(index: 10)
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
            .staggeredAppear(index: 11)
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
            .staggeredAppear(index: 12)
        }

        HealthDataQACard(isAvailable: HealthDataQAService.isAvailable) {
            isShowingHealthDataQA = true
        }
        .staggeredAppear(index: 13)
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
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("dashboard-pinned-grid")
        }
    }

    // MARK: - Daily Progress Ring Data (using pre-computed ViewModel values)

    private var stepsProgress: Double { viewModel.todayStepsValue / 10000 }
    private var stepsValueText: String { Int(viewModel.todayStepsValue).formattedWithSeparator }
    private var sleepProgress: Double { viewModel.todaySleepMinutes / 480 }

    private var sleepValueText: String {
        let minutes = viewModel.todaySleepMinutes
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private var dashboardLoadTrigger: String {
        launchExperienceReady ? "\(refreshSignal)-\(canLoadHealthKitData)" : "blocked"
    }

    private func loadDashboard() async {
        viewModel.recentHighRPEStreak = DashboardViewModel.computeHighRPEStreak(from: exerciseRecords)
        await viewModel.loadData(canLoadHealthKitData: canLoadHealthKitData)
        viewModel.updateYesterdayWorkoutSummary(from: Array(exerciseRecords))
        guard !viewModel.isLoading else { return }
        if !hasAppeared {
            withAnimation(.easeOut(duration: 0.3)) {
                hasAppeared = true
            }
        }
        reloadUnreadCount()

        // Template nudge (non-blocking, after main data loaded)
        let snapshots = templates.map {
            TemplateSnapshot(exerciseDefinitionIDs: $0.exerciseEntries.map(\.exerciseDefinitionID))
        }
        await viewModel.loadTemplateNudge(existingTemplateSnapshots: snapshots)
    }

    @State private var weatherDetailNavigation: WeatherSnapshot?

    private var notificationBellIcon: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
                .frame(width: 22, height: 22)
                .padding([.top, .trailing], 4)

            if combinedUnreadCount > 0 {
                Text(unreadBadgeLabel)
                    .accessibilityIdentifier("dashboard-notifications-unread-badge")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.red, in: Capsule())
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }

    private var unreadBadgeLabel: String {
        combinedUnreadCount > 99 ? "99+" : combinedUnreadCount.formatted()
    }

    private var combinedUnreadCount: Int {
        unreadNotificationCount + (hasUnreadRelease ? 1 : 0)
    }

    private func reloadUnreadCount() {
        unreadNotificationCount = inboxManager.unreadCount()
        hasUnreadRelease = WhatsNewInboxRelease.current()?.isUnread ?? false
    }

    @ToolbarContentBuilder
    private var dashboardToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button {
                    onOpenNotifications()
                } label: {
                    notificationBellIcon
                }
                .accessibilityLabel("Notifications")
                .accessibilityValue(combinedUnreadCount > 0
                    ? Text("\(combinedUnreadCount) unread notifications")
                    : Text("Inbox is all caught up"))
                .accessibilityIdentifier("dashboard-toolbar-notifications")

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("dashboard-toolbar-settings")
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func openMetric(_ metric: HealthMetric) {
        isShowingHealthDataQA = false
        inspectedMetric = metric
    }

    private func cardGrid(cards: [VitalCardData]) -> some View {
        let rows: [(left: VitalCardData, right: VitalCardData?, index: Int)] =
            stride(from: 0, to: cards.count, by: 2).map { index in
                (left: cards[index], right: index + 1 < cards.count ? cards[index + 1] : nil, index: index)
            }

        return VStack(spacing: DS.Spacing.md) {
            ForEach(rows, id: \.left.id) { row in
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    metricCard(row.left, index: row.index)
                    if let right = row.right {
                        metricCard(right, index: row.index + 1)
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }

    private func metricCard(_ card: VitalCardData, index: Int) -> some View {
        Button {
            openMetric(card.metric)
        } label: {
            VitalCard(data: card, animationIndex: index)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
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

// MARK: - Cache Sync Modifier (extracted to help type-checker)

/// Consolidates @Observable → @State cache synchronization into a single ViewModifier
/// to reduce the modifier chain depth in the main body and help the type-checker.
private struct DashboardCacheSync: ViewModifier {
    let viewModel: DashboardViewModel
    @Binding var cachedWeatherAtmosphere: WeatherAtmosphere
    @Binding var cachedFocusInsight: CoachingInsight?
    @Binding var cachedCoachingMessage: String?
    @Binding var cachedWeatherSnapshot: WeatherSnapshot?
    @Binding var cachedWeatherCardInsight: WeatherCard.InsightInfo?
    @Binding var isShowingBriefing: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.weatherAtmosphere) { _, new in cachedWeatherAtmosphere = new }
            .onChange(of: viewModel.focusInsight) { _, new in cachedFocusInsight = new }
            .onChange(of: viewModel.coachingMessage) { _, new in cachedCoachingMessage = new }
            .onChange(of: viewModel.weatherSnapshot) { _, new in cachedWeatherSnapshot = new }
            .onChange(of: viewModel.weatherCardInsight) { _, new in cachedWeatherCardInsight = new }
            .onChange(of: viewModel.briefingData == nil) { _, isNil in if isNil { isShowingBriefing = false } }
    }
}

#Preview {
    DashboardView()
}
