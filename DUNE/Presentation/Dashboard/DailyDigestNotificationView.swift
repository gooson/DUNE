import SwiftUI

/// Shows the current day's digest when its notification is opened.
struct DailyDigestNotificationView: View {
    @State private var viewModel: DashboardViewModel
    @State private var hasLoaded = false
    @State private var showsFullSummary = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let canLoadHealthKitData: Bool
    let hasFailedHealthKitAuthorization: Bool

    init(
        sharedHealthDataService: SharedHealthDataService? = nil,
        scoreRefreshService: ScoreRefreshService? = nil,
        canLoadHealthKitData: Bool = true,
        hasFailedHealthKitAuthorization: Bool = false
    ) {
        _viewModel = State(initialValue: DashboardViewModel(
            sharedHealthDataService: sharedHealthDataService,
            scoreRefreshService: scoreRefreshService
        ))
        self.canLoadHealthKitData = canLoadHealthKitData
        self.hasFailedHealthKitAuthorization = hasFailedHealthKitAuthorization
    }

    var body: some View {
        ScrollView {
            Group {
                if hasFailedHealthKitAuthorization {
                    EmptyStateView(
                        icon: "heart.text.clipboard",
                        title: "Health Data Unavailable",
                        message: "Close and reopen DUNE to try again."
                    )
                } else if !isReadyToLoad || !hasLoaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, DS.Spacing.xxxl)
                        .accessibilityIdentifier("notification-daily-digest-loading")
                } else if let digest = viewModel.dailyDigest,
                          !viewModel.sortedMetrics.isEmpty || viewModel.conditionScore != nil {
                    report(for: digest)
                } else {
                    EmptyStateView(
                        icon: "heart.text.clipboard",
                        title: "No Health Data",
                        message: "Grant HealthKit access to see your daily metrics."
                    )
                }
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.lg)
        }
        .accessibilityIdentifier("notification-daily-digest-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Today's Report")
        .task(id: isReadyToLoad) {
            guard isReadyToLoad else { return }
            await viewModel.loadData(
                canLoadHealthKitData: canLoadHealthKitData,
                forceDailyDigest: true
            )
            guard !Task.isCancelled else { return }
            hasLoaded = true
        }
    }

    private var isReadyToLoad: Bool {
        canLoadHealthKitData || !HealthKitManager.shared.isAvailable
    }

    private func report(for digest: DailyDigest) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            cover(for: digest)
            conditionSection(digest.metrics)
            activitySection(digest.metrics)
            sleepSection(digest.metrics)
            narrativeSection(digest)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("dashboard-daily-digest")
    }

    private func cover(for digest: DailyDigest) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top) {
                Text(digest.date, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("dashboard-digest-date")
                Spacer(minLength: DS.Spacing.md)
                Image(systemName: "doc.text")
                    .font(.system(size: 36, weight: .light))
                    .frame(width: 68, height: 68)
                    .background(DS.Color.surfacePrimary.opacity(DS.Opacity.overlay), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .accessibilityHidden(true)
            }
            Text("Today's Report")
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("dashboard-digest-header")
        }
        .foregroundStyle(DS.Color.onBrightAction)
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [DS.Color.warmGlow, DS.Color.desertBronze], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: DS.Radius.xxl)
        )
        .accessibilityIdentifier("notification-daily-digest-cover")
    }

    @ViewBuilder
    private func conditionSection(_ metrics: DailyDigest.DigestMetrics) -> some View {
        if let score = metrics.conditionScore {
            reportCard(symbol: "heart.text.clipboard", title: "Condition", color: DS.Color.warmGlow) {
                Text(score.formattedWithSeparator)
                    .font(DS.Typography.heroScore)
                    .monospacedDigit()
                    .accessibilityIdentifier("dashboard-digest-condition")
                if let delta = metrics.conditionDelta, delta != 0 {
                    Text("From yesterday: \(Double(delta).formattedWithSeparator(alwaysShowSign: true))")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .accessibilityIdentifier("notification-daily-digest-condition")
        }
    }

    @ViewBuilder
    private func activitySection(_ metrics: DailyDigest.DigestMetrics) -> some View {
        if metrics.stepsCount != nil || metrics.workoutSummary != nil {
            reportCard(symbol: "figure.walk", title: "Activity", color: DS.Color.activity) {
                if let steps = metrics.stepsCount {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text("Steps")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                        Text(steps.formattedWithSeparator)
                            .font(DS.Typography.heroScore)
                            .monospacedDigit()
                            .accessibilityIdentifier("dashboard-digest-steps")
                    }
                }
                if let workout = metrics.workoutSummary, !workout.isEmpty {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.sm))
                    layout {
                        Label("Workout", systemImage: "figure.run")
                            .fontWeight(.semibold)
                        Text(workout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .accessibilityIdentifier("notification-daily-digest-workout")
                }
            }
            .accessibilityIdentifier("notification-daily-digest-activity")
        }
    }

    @ViewBuilder
    private func sleepSection(_ metrics: DailyDigest.DigestMetrics) -> some View {
        if let minutes = metrics.sleepMinutes, minutes.isFinite, minutes > 0 {
            reportCard(symbol: "moon.fill", title: "Sleep", color: DS.Color.sleep) {
                Text(minutes.hoursMinutesFormatted)
                    .font(DS.Typography.heroScore)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("notification-daily-digest-sleep")
        }
    }

    private func narrativeSection(_ digest: DailyDigest) -> some View {
        let metrics = digest.metrics
        let hasRecordedMetrics = metrics.conditionScore != nil || metrics.workoutSummary != nil
            || (metrics.sleepMinutes.map { $0.isFinite && $0 > 0 } ?? false)
            || metrics.stepsCount != nil || metrics.stressLevel != nil
        let text = DailyDigestSummaryText(digest.summary)
        return reportCard(symbol: "text.alignleft", title: "Day in Review", color: DS.Color.desertBronze) {
            if !hasRecordedMetrics || text.full.isEmpty {
                Text("Today's records are still being collected.")
                    .foregroundStyle(DS.Color.textSecondary)
            } else {
                Text(showsFullSummary ? text.full : text.preview)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(showsFullSummary
                        ? "dashboard-digest-full-summary" : "dashboard-digest-preview")
                if text.canExpand {
                    Button {
                        withAnimation(reduceMotion ? nil : DS.Animation.snappy) {
                            showsFullSummary.toggle()
                        }
                    } label: {
                        Group {
                            if showsFullSummary {
                                Text("Collapse summary")
                            } else {
                                Text("Expand summary")
                            }
                        }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(CardNavigationButtonStyle())
                    .accessibilityValue(showsFullSummary ? Text("Expanded") : Text("Collapsed"))
                    .accessibilityIdentifier("dashboard-digest-summary-toggle")
                }
            }
        }
        .accessibilityIdentifier("notification-daily-digest-narrative")
    }

    private func reportCard<Content: View>(
        symbol: String,
        title: LocalizedStringKey,
        color: Color,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        StandardCard(padding: DS.Spacing.xl) {
            VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? DS.Spacing.lg : DS.Spacing.md) {
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    Label(title, systemImage: symbol)
                        .font(DS.Typography.sectionTitle)
                        .foregroundStyle(color)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 0)
                        Image(systemName: symbol)
                            .font(.system(size: 48, weight: .ultraLight))
                            .foregroundStyle(color)
                            .accessibilityHidden(true)
                    }
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        DailyDigestNotificationView()
    }
}
