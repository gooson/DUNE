import SwiftUI

/// Statistics for the chart's current viewport, including the accepted row cadence.
struct MetricHistorySummary: View {
    let category: HealthMetric.Category
    let summary: MetricVisibleSummary?
    let unitOverride: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var iconColumn: CGFloat = 22

    private var formatter: MetricDetailValueFormatter {
        MetricDetailValueFormatter(category: category, unitOverride: displayUnit)
    }

    private var displayUnit: String {
        if category == .sleep { return "" }
        if let unit = summary?.unit, !unit.isEmpty { return unit }
        return unitOverride
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let summary {
                Text(summary.basis.displayName)
                    .font(.caption)
                    .accessibilityIdentifier("detail-chart-summary-basis")
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Exercise already has its dedicated visible totals section below the chart.
            if category == .steps {
                stat(label: "Total", icon: "sum", value: summary?.total, identifier: "detail-chart-summary-total")
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.md) { stats }
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.sm) { stats }
            }

            if let change = summary?.statistics.changePercentage, change.isFinite {
                comparison(change)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("detail-chart-visible-summary")
    }

    @ViewBuilder
    private var stats: some View {
        stat(label: "Avg", icon: "chart.bar.xaxis", value: summary?.statistics.average, identifier: "detail-chart-summary-average")
        stat(label: "Min", icon: "arrow.down", value: summary?.statistics.min, identifier: "detail-chart-summary-minimum")
        stat(label: "Max", icon: "arrow.up", value: summary?.statistics.max, identifier: "detail-chart-summary-maximum")
    }

    private func stat(
        label: LocalizedStringKey, icon: String, value: Double?, identifier: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(category.themeColor)
                .frame(width: iconColumn)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                Text(value.map { formatter.string(from: $0) } ?? "—")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if !displayUnit.isEmpty {
                    Text(displayUnit)
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func comparison(_ change: Double) -> some View {
        let magnitude = abs(change).formattedWithSeparator(fractionDigits: 1)
        let direction = change == 0 ? "equal" : (change > 0 ? "arrow.up.right" : "arrow.down.right")
        let tint: Color = switch category {
        case .weight, .bmi, .bodyFat, .leanBodyMass: category.themeColor
        case .rhr, .heartRate: change > 0 ? DS.Color.negative : DS.Color.positive
        default: change > 0 ? DS.Color.positive : DS.Color.negative
        }

        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: direction)
                Text("\(magnitude)%")
                    .monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(change == 0 ? Color.secondary : tint)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .background((change == 0 ? Color.secondary : tint).opacity(0.12), in: Capsule())

            Group {
                if change > 0 {
                    Text(String(localized: "Your average is \(magnitude)% higher than last period"))
                } else if change < 0 {
                    Text(String(localized: "Your average is \(magnitude)% lower than last period"))
                } else {
                    Text("Your average is unchanged from last period")
                }
            }
            .font(.caption)
            .foregroundStyle(DS.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
