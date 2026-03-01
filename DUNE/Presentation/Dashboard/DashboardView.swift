import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @State private var isShowingPinnedEditor = false
    @State private var hasAppeared = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openURL) private var openURL
    private let scrollToTopSignal: Int

    private enum ScrollAnchor: Hashable {
        case top
    }

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    private let refreshSignal: Int

    init(sharedHealthDataService: SharedHealthDataService? = nil, scrollToTopSignal: Int = 0, refreshSignal: Int = 0) {
        _viewModel = State(initialValue: DashboardViewModel(sharedHealthDataService: sharedHealthDataService))
        self.scrollToTopSignal = scrollToTopSignal
        self.refreshSignal = refreshSignal
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id(ScrollAnchor.top)

                VStack(spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                    if viewModel.isLoading && viewModel.sortedMetrics.isEmpty {
                        DashboardSkeletonView()
                    } else if viewModel.sortedMetrics.isEmpty && !viewModel.isLoading {
                        if viewModel.errorMessage != nil {
                            errorSection
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
                                    trendBadges: viewModel.heroBaselineDetails
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dashboard-hero-condition")
                        } else if let status = viewModel.baselineStatus, !status.isReady {
                            BaselineProgressView(status: status)
                        }

                        // Weather + coaching (merged when coaching is weather-category)
                        if let weather = viewModel.weatherSnapshot {
                            NavigationLink(value: weather) {
                                WeatherCard(snapshot: weather, insightInfo: viewModel.weatherCardInsight)
                            }
                            .buttonStyle(.plain)
                        } else {
                            WeatherCardPlaceholder {
                                Task { await viewModel.requestLocationPermission() }
                            }
                        }

                        // Coaching (standalone when not merged into weather card)
                        if let insight = viewModel.standaloneCoachingInsight {
                            TodayCoachingCard(insight: insight)
                        } else if viewModel.focusInsight == nil,
                                  let coachingMessage = viewModel.coachingMessage {
                            TodayCoachingCard(message: coachingMessage)
                        }

                        // Insight Cards
                        if !viewModel.insightCards.isEmpty {
                            insightCardsSection
                        }

                        // Pinned Metrics
                        if !viewModel.pinnedCards.isEmpty {
                            pinnedSection
                        }

                        // Last updated + error banner
                        if let lastUpdated = viewModel.lastUpdated {
                            Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        // Condition (HRV, RHR)
                        if !viewModel.conditionCards.isEmpty {
                            cardSection(
                                title: "Condition",
                                icon: "heart.fill",
                                iconColor: DS.Color.vitals,
                                cards: viewModel.conditionCards
                            )
                        }

                        // Activity (Steps, Exercise)
                        if !viewModel.activityCards.isEmpty {
                            cardSection(
                                title: "Activity",
                                icon: "figure.run",
                                iconColor: DS.Color.activity,
                                cards: viewModel.activityCards
                            )
                        }

                        // Body (Weight, BMI, Sleep)
                        if !viewModel.bodyCards.isEmpty {
                            cardSection(
                                title: "Body",
                                icon: "bed.double.fill",
                                iconColor: DS.Color.body,
                                cards: viewModel.bodyCards
                            )
                        }
                    }
                }
                .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
            }
            .onChange(of: scrollToTopSignal) { _, _ in
                withAnimation(DS.Animation.standard) {
                    proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                }
            }
        }
        .environment(\.weatherAtmosphere, viewModel.weatherAtmosphere)
        .background { TabWaveBackground() }
        .navigationDestination(for: ConditionScore.self) { score in
            ConditionScoreDetailView(score: score)
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
            await viewModel.loadData()
        }
        .task(id: refreshSignal) {
            await viewModel.loadData()
            withAnimation(.easeOut(duration: 0.3)) {
                hasAppeared = true
            }
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
        .navigationTitle(Text(verbatim: "Today"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("dashboard-toolbar-settings")
            }
        }
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

                Button("Edit") {
                    isShowingPinnedEditor = true
                }
                .font(.subheadline.weight(.medium))
                .accessibilityIdentifier("dashboard-pinned-edit")
            }
            .padding(.horizontal, DS.Spacing.xs)

            cardGrid(cards: viewModel.pinnedCards)
        }
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
        title: String,
        icon: String,
        iconColor: Color,
        cards: [VitalCardData]
    ) -> some View {
        SectionGroup(title: title, icon: icon, iconColor: iconColor) {
            cardGrid(cards: cards)
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func cardGrid(cards: [VitalCardData]) -> some View {
        LazyVGrid(columns: gridColumns, spacing: DS.Spacing.md) {
            ForEach(cards.indices, id: \.self) { index in
                let card = cards[index]
                NavigationLink(value: card.metric) {
                    VitalCard(data: card, animationIndex: index)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
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
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "Something Went Wrong",
            message: viewModel.errorMessage ?? "An unexpected error occurred.",
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
}

// MARK: - Baseline Progress

private struct BaselineProgressView: View {
    let status: BaselineStatus

    var body: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.md) {
                Text("Establishing Baseline")
                    .font(.headline)

                ProgressView(value: status.progress)
                    .tint(DS.Color.hrv)

                Text("\(status.daysCollected)/\(status.daysRequired) days")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }
}

#Preview {
    DashboardView()
}
