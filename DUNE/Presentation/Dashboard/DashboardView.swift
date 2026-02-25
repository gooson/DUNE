import SwiftUI

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @State private var isShowingPinnedEditor = false
    @State private var hasAppeared = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openURL) private var openURL

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    init(sharedHealthDataService: SharedHealthDataService? = nil) {
        _viewModel = State(initialValue: DashboardViewModel(sharedHealthDataService: sharedHealthDataService))
    }

    var body: some View {
        ScrollView {
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
                    } else if let status = viewModel.baselineStatus, !status.isReady {
                        BaselineProgressView(status: status)
                    }

                    // Coaching
                    if let coachingMessage = viewModel.coachingMessage {
                        TodayCoachingCard(message: coachingMessage)
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
        .background { TabWaveBackground(primaryColor: .accentColor) }
        .navigationDestination(for: ConditionScore.self) { score in
            ConditionScoreDetailView(score: score)
        }
        .navigationDestination(for: HealthMetric.self) { metric in
            MetricDetailView(metric: metric)
        }
        .navigationDestination(for: AllDataDestination.self) { destination in
            AllDataView(category: destination.category)
        }
        .waveRefreshable(
            color: .accentColor
        ) {
            await viewModel.loadData()
        }
        .task {
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
        .navigationTitle("Today")
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
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Edit") {
                    isShowingPinnedEditor = true
                }
                .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, DS.Spacing.xs)

            cardGrid(cards: viewModel.pinnedCards)
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
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    DashboardView()
}
