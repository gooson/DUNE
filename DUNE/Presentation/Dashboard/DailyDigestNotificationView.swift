import SwiftUI

/// Shows the current day's digest when its notification is opened.
struct DailyDigestNotificationView: View {
    @State private var viewModel: DashboardViewModel
    @State private var hasLoaded = false

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
                    VStack(spacing: DS.Spacing.md) {
                        DailyDigestCard(digest: digest)
                        sleepMetric(for: digest.metrics)
                    }
                } else {
                    EmptyStateView(
                        icon: "heart.text.clipboard",
                        title: "No Health Data",
                        message: "Grant HealthKit access to see your daily metrics."
                    )
                }
            }
            .padding(DS.Spacing.lg)
        }
        .accessibilityIdentifier("notification-daily-digest-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Today's Summary")
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

    @ViewBuilder
    private func sleepMetric(for metrics: DailyDigest.DigestMetrics) -> some View {
        if let minutes = metrics.sleepMinutes, minutes.isFinite, minutes > 0 {
            metricCard("Sleep", value: minutes.hoursMinutesFormatted, symbol: "moon.fill", color: DS.Color.sleep)
                .accessibilityIdentifier("notification-daily-digest-sleep")
        }
    }

    private func metricCard(
        _ title: LocalizedStringKey,
        value: String,
        symbol: String,
        color: Color
    ) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Label(title, systemImage: symbol)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(value)
                    .font(DS.Typography.cardScore)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        DailyDigestNotificationView()
    }
}
