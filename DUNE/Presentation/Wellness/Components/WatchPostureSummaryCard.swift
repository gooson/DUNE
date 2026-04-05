import SwiftUI

/// Displays the daily posture summary received from Apple Watch.
/// Shows sitting time, walking time, and stretch reminders triggered.
/// When no data is available, shows a guidance message based on the monitoring state.
struct WatchPostureSummaryCard: View {
    let summary: DailyPostureSummary?
    let isWatchAppInstalled: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header
                header

                switch cardState {
                case .hasData(let data):
                    metricsRow(data)
                case .monitoringDisabled, .notWorn, .watchNotInstalled:
                    emptyState
                }
            }
        }
    }

    // MARK: - Card State

    private enum CardState {
        case hasData(DailyPostureSummary)
        case monitoringDisabled
        case notWorn
        case watchNotInstalled
    }

    private var cardState: CardState {
        guard isWatchAppInstalled else { return .watchNotInstalled }
        guard let summary else { return .notWorn }

        if !summary.isMonitoringEnabled {
            return .monitoringDisabled
        }
        if summary.hasNoActivityData {
            return .notWorn
        }
        return .hasData(summary)
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
            if case .hasData = cardState {
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
        switch cardState {
        case .watchNotInstalled:
            return "applewatch.slash"
        case .monitoringDisabled:
            return "pause.circle"
        case .notWorn:
            return "applewatch.and.arrow.forward"
        case .hasData:
            return "figure.stand"
        }
    }

    private var emptyStateTitle: String {
        switch cardState {
        case .watchNotInstalled:
            return String(localized: "Apple Watch required")
        case .monitoringDisabled:
            return String(localized: "Posture monitoring disabled")
        case .notWorn:
            return String(localized: "Wear your Apple Watch")
        case .hasData:
            return ""
        }
    }

    private var emptyStateMessage: String {
        switch cardState {
        case .watchNotInstalled:
            return String(localized: "Pair an Apple Watch to monitor your posture throughout the day.")
        case .monitoringDisabled:
            return String(localized: "Open DUNE on Apple Watch → tap ⚙️ at top right → enable Posture Monitoring.")
        case .notWorn:
            return String(localized: "Put on your Apple Watch to start tracking sitting time and walking posture.")
        case .hasData:
            return ""
        }
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
