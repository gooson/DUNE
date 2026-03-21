import SwiftUI

/// Displays the daily posture summary received from Apple Watch.
/// Shows sitting time, walking time, and stretch reminders triggered.
struct WatchPostureSummaryCard: View {
    let summary: DailyPostureSummary

    @Environment(\.appTheme) private var theme

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "applewatch")
                        .font(.caption)
                        .foregroundStyle(DS.Color.body)
                    Text("Watch Posture")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Color.textSecondary)
                    Spacer(minLength: 0)
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textTertiary)
                }

                // Metrics row
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
        }
    }

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
