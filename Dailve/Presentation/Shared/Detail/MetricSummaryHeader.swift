import SwiftUI

/// Summary header for metric detail view showing current value, period stats, and change badge.
struct MetricSummaryHeader: View {
    let category: HealthMetric.Category
    let currentValue: Double
    let summary: MetricSummary?
    let lastUpdated: Date?
    var unitOverride: String?

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Category icon + name
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: category.iconName)
                    .foregroundStyle(category.themeColor)
                Text(category.displayName)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            // Large current value
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                Text(formattedCurrentValue)
                    .font(sizeClass == .regular ? DS.Typography.heroScore : DS.Typography.cardScore)
                    .fontDesign(.rounded)

                Text(resolvedUnit)
                    .font(sizeClass == .regular ? .title2 : .title3)
                    .foregroundStyle(.secondary)
            }

            // Period summary stats (always visible — shows "—" placeholders when loading)
            HStack(spacing: DS.Spacing.lg) {
                statItem(label: "Avg", value: summary.map { formatValue($0.average) } ?? "—")
                if sizeClass == .regular { statDivider }
                statItem(label: "Min", value: summary.map { formatValue($0.min) } ?? "—")
                if sizeClass == .regular { statDivider }
                statItem(label: "Max", value: summary.map { formatValue($0.max) } ?? "—")

                if let change = summary?.changePercentage {
                    changeBadge(change)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: summary?.average)

            // Comparison sentence (fixed height to prevent layout shift)
            comparisonSentence(summary?.changePercentage)

            // Last updated
            if let lastUpdated {
                Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.displayName), \(formattedCurrentValue) \(resolvedUnit)")
    }

    // MARK: - Subviews

    private var statDivider: some View {
        Divider()
            .frame(height: 24)
    }

    private func statItem(label: String, value: String) -> some View {
        let valueFont: Font = sizeClass == .regular ? .subheadline : .caption
        return VStack(spacing: DS.Spacing.xxs) {
            Text(label)
                .font(sizeClass == .regular ? .caption : .caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(valueFont)
                .fontWeight(.medium)
                .contentTransition(.numericText())
                .frame(minHeight: sizeClass == .regular ? 20 : 16)
        }
    }

    private func changeBadge(_ change: Double) -> some View {
        let isPositive = change > 0
        let icon = change == 0 ? "equal" : (isPositive ? "arrow.up.right" : "arrow.down.right")
        let color: Color = change == 0 ? .secondary : badgeColor(isPositive: isPositive)

        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(String(format: "%.1f", abs(change)))%")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Helpers

    private var resolvedUnit: String {
        unitOverride ?? category.unitLabel
    }

    private var formattedCurrentValue: String {
        formatValue(currentValue)
    }

    private func formatValue(_ value: Double) -> String {
        // Use distance formatting when unit is km
        if let override = unitOverride, override == "km" {
            return String(format: "%.1f", value)
        }
        return switch category {
        case .hrv:               String(format: "%.0f", value)
        case .rhr:               String(format: "%.0f", value)
        case .heartRate:         String(format: "%.0f", value)
        case .sleep:             value.hoursMinutesFormatted
        case .exercise:          String(format: "%.0f", value)
        case .steps:             String(format: "%.0f", value)
        case .weight:            String(format: "%.1f", value)
        case .bmi:               String(format: "%.1f", value)
        case .bodyFat:           String(format: "%.1f", value)
        case .leanBodyMass:      String(format: "%.1f", value)
        case .spo2:              String(format: "%.0f", value * 100)
        case .respiratoryRate:   String(format: "%.0f", value)
        case .vo2Max:            String(format: "%.1f", value)
        case .heartRateRecovery: String(format: "%.0f", value)
        case .wristTemperature:  String(format: "%+.1f", value)
        }
    }

    @ViewBuilder
    private func comparisonSentence(_ change: Double?) -> some View {
        Group {
            if let change {
                let direction = change > 0 ? "higher" : "lower"
                let absChange = String(format: "%.1f", abs(change))
                Text("Your average is \(absChange)% \(direction) than last period")
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .font(.caption)
        .frame(minHeight: 16, alignment: .leading)
    }

    private func badgeColor(isPositive: Bool) -> Color {
        switch category {
        case .rhr:
            isPositive ? DS.Color.negative : DS.Color.positive
        default:
            isPositive ? DS.Color.positive : DS.Color.negative
        }
    }
}
