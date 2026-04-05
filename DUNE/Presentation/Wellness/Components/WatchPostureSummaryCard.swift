import SwiftUI

/// Displays the daily posture summary received from Apple Watch.
/// Shows sitting time, walking time, and stretch reminders triggered.
/// When no data is available, shows a guidance message based on the monitoring state.
struct WatchPostureSummaryCard: View {
    let summary: DailyPostureSummary?
    let isWatchAppInstalled: Bool

    @Environment(\.appTheme) private var theme

    var body: some View {
        let state = cardState
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                header(state: state)

                switch state {
                case .hasData(let data):
                    metricsRow(data)
                case .monitoringDisabled, .notWorn, .watchNotInstalled:
                    emptyStateView(state: state)
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

    private func header(state: CardState) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "applewatch")
                .font(.caption)
                .foregroundStyle(DS.Color.body)
            Text("Watch Posture")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(DS.Color.textSecondary)
            Spacer(minLength: 0)
            if case .hasData = state {
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

    private func emptyStateView(state: CardState) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: emptyStateIcon(for: state))
                .font(.title3)
                .foregroundStyle(DS.Color.textTertiary)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(emptyStateTitle(for: state))
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Color.textSecondary)
                Text(emptyStateMessage(for: state))
                    .font(.caption)
                    .foregroundStyle(DS.Color.textTertiary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private func emptyStateIcon(for state: CardState) -> String {
        switch state {
        case .watchNotInstalled: "applewatch.slash"
        case .monitoringDisabled: "pause.circle"
        case .notWorn: "applewatch.and.arrow.forward"
        case .hasData: "figure.stand"
        }
    }

    private func emptyStateTitle(for state: CardState) -> String {
        switch state {
        case .watchNotInstalled: String(localized: "Apple Watch required")
        case .monitoringDisabled: String(localized: "Posture monitoring disabled")
        case .notWorn: String(localized: "Wear your Apple Watch")
        case .hasData: ""
        }
    }

    private func emptyStateMessage(for state: CardState) -> String {
        switch state {
        case .watchNotInstalled:
            String(localized: "Pair an Apple Watch to monitor your posture throughout the day.")
        case .monitoringDisabled:
            String(localized: "Open DUNE on Apple Watch → tap ⚙️ at top right → enable Posture Monitoring.")
        case .notWorn:
            String(localized: "Put on your Apple Watch to start tracking sitting time and walking posture.")
        case .hasData:
            ""
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
