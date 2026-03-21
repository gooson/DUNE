import SwiftUI

/// Displays the daily posture summary received from Apple Watch.
/// Shows sitting time, walking time, and stretch reminders triggered.
/// When no data is available, shows a guidance message.
struct WatchPostureSummaryCard: View {
    let summary: DailyPostureSummary?
    let isWatchAppInstalled: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header
                header

                if let summary {
                    metricsRow(summary)
                } else {
                    emptyState
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "applewatch")
                .font(.caption)
                .foregroundStyle(DS.Color.body)
            Text("Watch Posture")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(DS.Color.textSecondary)
            Spacer(minLength: 0)
            if summary != nil {
                Text("Today")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textTertiary)
            }
        }
    }

    // MARK: - Metrics

    private func metricsRow(_ summary: DailyPostureSummary) -> some View {
        HStack(spacing: DS.Spacing.lg) {
            metricItem(
                icon: "figure.seated.seatbelt",
                value: PostureFormatting.formatMinutes(summary.sedentaryMinutes),
                label: "Sitting"
            )

            metricItem(
                icon: "figure.walk",
                value: PostureFormatting.formatMinutes(summary.walkingMinutes),
                label: "Walking"
            )

            if summary.stretchRemindersTriggered > 0 {
                metricItem(
                    icon: "bell.fill",
                    value: "\(summary.stretchRemindersTriggered)",
                    label: "Reminders"
                )
            }

            if let gaitScore = summary.averageGaitScore {
                metricItem(
                    icon: "waveform.path.ecg",
                    value: "\(gaitScore)",
                    label: "Gait"
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: emptyStateIcon)
                .font(.title3)
                .foregroundStyle(DS.Color.textTertiary)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(emptyStateTitle)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Color.textSecondary)
                Text(emptyStateMessage)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textTertiary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private var emptyStateIcon: String {
        isWatchAppInstalled ? "figure.stand" : "applewatch.slash"
    }

    private var emptyStateTitle: String {
        if isWatchAppInstalled {
            return String(localized: "No posture data yet")
        }
        return String(localized: "Apple Watch required")
    }

    private var emptyStateMessage: String {
        if isWatchAppInstalled {
            return String(localized: "Open DUNE on Apple Watch → tap ⚙️ at top right → enable Posture Monitoring.")
        }
        return String(localized: "Pair an Apple Watch to monitor your posture throughout the day.")
    }

    // MARK: - Metric Item

    private func metricItem(icon: String, value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(DS.Color.body)
            Text(value)
                .font(.system(.callout, design: .rounded).bold())
                .foregroundStyle(theme.heroTextGradient)
            Text(label)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }
}
