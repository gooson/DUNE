import SwiftUI

/// Consolidated recovery & sleep card combining sleep deficit gauge with sleep-related insights.
/// Replaces the separate SleepDeficitBadgeView and sleep-category InsightCards.
struct RecoverySleepCard: View {
    let sleepDeficit: SleepDeficitAnalysis?
    let sleepInsights: [InsightCardData]
    let sleepMetric: HealthMetric?
    let onDismissInsight: (String) -> Void

    var body: some View {
        if shouldShow {
            InlineCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    header
                    deficitRow
                    insightRows
                }
            }
            .accessibilityIdentifier("dashboard-recovery-sleep-card")
        }
    }

    private var shouldShow: Bool {
        hasValidDeficit || !sleepInsights.isEmpty
    }

    private var hasValidDeficit: Bool {
        guard let deficit = sleepDeficit else { return false }
        return deficit.level != .insufficient
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "bed.double.fill")
                .font(.caption2)
                .foregroundStyle(DS.Color.body)

            Text("Recovery & Sleep")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Deficit Row

    @ViewBuilder
    private var deficitRow: some View {
        if let deficit = sleepDeficit, hasValidDeficit {
            let levelColor = deficit.level.color
            HStack(spacing: DS.Spacing.md) {
                // Mini ring gauge
                ZStack {
                    Circle()
                        .stroke(levelColor.opacity(DS.Opacity.border), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(deficit.weeklyDeficit / 600.0, 1.0))
                        .stroke(levelColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(deficit.formattedWeeklyDeficit)
                            .font(.subheadline.bold().monospacedDigit())

                        Text(deficit.level.label)
                            .font(.caption2)
                            .foregroundStyle(levelColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(levelColor.opacity(0.12), in: Capsule())
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Sleep Insights

    @ViewBuilder
    private var insightRows: some View {
        if !sleepInsights.isEmpty {
            if hasValidDeficit {
                Divider().opacity(0.3)
            }

            VStack(spacing: DS.Spacing.xs) {
                ForEach(sleepInsights.prefix(2)) { card in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: card.iconName)
                            .font(.caption)
                            .foregroundStyle(card.category.iconColor)
                            .frame(width: 20)

                        Text(card.message)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(3)

                        Spacer(minLength: 0)

                        Button {
                            onDismissInsight(card.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Detail Link

    @ViewBuilder
    private var detailLink: some View {
        if let metric = sleepMetric {
            Divider().opacity(0.3)

            NavigationLink(value: metric) {
                HStack {
                    Spacer()
                    Text("Sleep Details")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.tint)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }
}
