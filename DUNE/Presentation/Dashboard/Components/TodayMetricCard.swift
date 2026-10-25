import SwiftUI

/// Compact metric presentation owned by Today; other tabs retain their card layout.
struct TodayMetricCard: View {
    let data: VitalCardData
    var isWorkout = false

    @Environment(\.appTheme) private var theme

    var body: some View {
        StandardCard(padding: 14) {
            Group {
                if isWorkout {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .center, spacing: 10) {
                            titleAndDate
                            Spacer(minLength: 8)
                            metricValue
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            titleAndDate
                            metricValue
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        titleAndDate
                        metricValue
                        if let detail = data.baselineDetail {
                            BaselineTrendBadge(detail: detail, inversePolarity: data.inversePolarity)
                        } else if let change = data.change {
                            changeLabel(change)
                        }
                        if data.sparklineData.count >= 2 {
                            MiniSparklineView(dataPoints: data.sparklineData, color: data.category.themeColor)
                                .frame(height: 24)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(data.isStale ? 0.85 : 1)
    }

    private var titleAndDate: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: data.metric.resolvedIconName)
                    .foregroundStyle(data.category.themeColor)
                    .accessibilityHidden(true)
                Text(data.title)
                    .foregroundStyle(DS.Color.textSecondary)
                    .accessibilityIdentifier("dashboard-workout-title-\(data.id)")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption.weight(.medium))
            Text(data.lastUpdated.freshnessLabel)
                .accessibilityIdentifier("dashboard-workout-date-\(data.id)")
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
                .accessibilityLabel(Text(data.lastUpdated, format: .dateTime.year().month(.abbreviated).day().hour().minute()))
        }
    }

    private var metricValue: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                valueText
                unitText
            }
            VStack(alignment: .leading, spacing: 2) {
                valueText
                unitText
            }
        }
    }

    private var valueText: some View {
        Text(data.value)
            .accessibilityIdentifier("dashboard-workout-value-\(data.id)")
            .font(.system(isWorkout ? .title3 : .title2, design: .rounded, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(theme.heroTextGradient)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var unitText: some View {
        if !data.unit.isEmpty {
            Text(data.unit)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func changeLabel(_ change: String) -> some View {
        Label(change, systemImage: data.changeIsPositive == true ? "arrow.up.right" : "arrow.down.right")
            .font(.caption2.weight(.medium))
            .foregroundStyle(data.changeIsPositive == true ? DS.Color.positive : DS.Color.negative)
    }
}
