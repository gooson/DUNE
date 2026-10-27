import SwiftUI

/// A Wellness-only metric tile. The caller owns the metric's NavigationLink.
struct WellnessMetricCard: View {
    let data: VitalCardData
    var comparison: WellnessBodyComparison? = nil
    var isBodyMetric = false

    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color { data.category.themeColor }

    private var trendValues: [Double] {
        let values = data.sparklineData
        guard values.count >= 2, values.allSatisfy(\.isFinite),
              !isBodyMetric || data.category == .weight || data.category == .bodyFat else { return [] }
        return values
    }

    private var validComparison: WellnessBodyComparison? {
        guard let comparison,
              comparison.currentDate == data.lastUpdated,
              abs(comparison.currentValue - data.metric.value) < 0.0001,
              comparison.change.isFinite,
              comparison.previousValue.isFinite else { return nil }
        return comparison
    }

    var body: some View {
        StandardCard(padding: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                CardNavigationHeader(minimumHeight: 44) {
                    Label(data.title, systemImage: data.metric.resolvedIconName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }

                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(data.value)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !data.unit.isEmpty {
                        Text(data.unit)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)

                if isBodyMetric {
                    bodyComparison
                } else {
                    healthContext
                }

                if !trendValues.isEmpty {
                    WellnessMetricSparkline(values: trendValues, color: tint)
                        .frame(height: 34)

                    Text("Recent records · own scale")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text("Recent records · own scale"))
                        .accessibilityValue(trendAccessibilityValue)
                }

                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    if data.isStale {
                        Text("Older record")
                    }
                    Text(data.lastUpdated.freshnessLabel)
                    Text(data.lastUpdated.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                }
                .font(.caption2)
                .foregroundStyle(data.isStale ? DS.Color.textSecondary : DS.Color.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(tint.opacity(colorScheme == .dark ? 0.10 : 0.06))
            }
        }
        .accessibilityIdentifier("wellness-card-\(data.category.rawValue)")
    }

    @ViewBuilder
    private var healthContext: some View {
        if let detail = data.baselineDetail {
            BaselineTrendBadge(detail: detail, inversePolarity: data.inversePolarity)
        } else if let change = data.change {
            Text(change)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var bodyComparison: some View {
        if let comparison = validComparison {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Image(systemName: comparison.change > 0 ? "arrow.up.right" : comparison.change < 0 ? "arrow.down.right" : "equal")
                    .accessibilityHidden(true)
                Text(comparison.change.formattedWithSeparator(fractionDigits: 1, alwaysShowSign: true))
                    .fontWeight(.semibold)
                Text(data.category == .bodyFat ? "%p" : data.unit)
            }
            .font(.caption)
            .foregroundStyle(DS.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Previous measurement")
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(comparison.previousValue.formattedWithSeparator(fractionDigits: 1))
                    if !data.unit.isEmpty {
                        Text(data.unit)
                    }
                    Text(comparison.previousDate.formatted(.dateTime.month(.abbreviated).day()))
                }
            }
            .font(.caption2)
            .foregroundStyle(DS.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("No comparison record")
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trendAccessibilityValue: String {
        guard let first = trendValues.first, let last = trendValues.last else { return "" }
        let start = first.formattedWithSeparator(fractionDigits: 1)
        let end = last.formattedWithSeparator(fractionDigits: 1)
        return "\(start) → \(end) \(data.unit)"
    }
}

#Preview("Health metric") {
    let metric = HealthMetric(
        id: "preview-hrv", name: "HRV", value: 48, unit: "ms",
        change: nil, date: .now, category: .hrv
    )
    WellnessMetricCard(data: VitalCardData(
        id: metric.id, category: .hrv, section: .active,
        title: "HRV", value: "48", unit: "ms",
        change: nil, changeIsPositive: nil,
        sparklineData: [51, 48, 49, 46, 48], metric: metric,
        lastUpdated: metric.date, isStale: false
    ))
    .padding()
}
