import SwiftUI

/// Today metrics share Wellness visual hierarchy; workout rows remain compact.
struct TodayMetricCard: View {
    let data: VitalCardData
    var isWorkout = false

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var tint: Color { data.category.themeColor }

    var body: some View {
        StandardCard(padding: isWorkout ? 14 : DS.Spacing.sm) {
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
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Label(data.title, systemImage: data.metric.resolvedIconName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: 44, alignment: .leading)
                        metricValue
                        if let detail = data.baselineDetail {
                            BaselineTrendBadge(detail: detail, inversePolarity: data.inversePolarity)
                        } else if let change = data.change {
                            changeLabel(change)
                        } else {
                            Text("No comparison record")
                                .font(.caption2).foregroundStyle(DS.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if data.sparklineData.count >= 2, data.sparklineData.allSatisfy(\.isFinite) {
                            MiniSparklineView(dataPoints: data.sparklineData, color: tint)
                                .frame(height: 34)
                            Text("Recent records · own scale")
                                .font(.caption2).foregroundStyle(DS.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(data.lastUpdated.freshnessLabel)
                            .font(.caption2).foregroundStyle(DS.Color.textSecondary)
                            .accessibilityLabel(Text(data.lastUpdated, format: .dateTime.year().month(.abbreviated).day().hour().minute()))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(DS.Spacing.sm)
                    .background {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(tint.opacity(colorScheme == .dark ? 0.10 : 0.06))
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
            .font(.system(isWorkout ? .title3 : .largeTitle, design: .rounded, weight: isWorkout ? .semibold : .bold))
            .monospacedDigit()
            .foregroundStyle(isWorkout ? AnyShapeStyle(theme.heroTextGradient) : AnyShapeStyle(Color.primary))
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


/// Measures each cell at its column width before proposing the tallest natural height.
struct TodayMetricRow: Layout {
    var spacing: CGFloat = 10
    var minimumCellWidth: CGFloat = 150

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let width = max(proposal.width ?? 0, minimumCellWidth * CGFloat(subviews.count) + gaps)
        let cellWidth = (width - gaps) / CGFloat(subviews.count)
        let height = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height
        }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let width = (bounds.width - spacing * CGFloat(subviews.count - 1)) / CGFloat(subviews.count)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + CGFloat(index) * (width + spacing), y: bounds.minY),
                          anchor: .topLeading, proposal: ProposedViewSize(width: width, height: bounds.height))
        }
    }
}

#Preview("Metric without comparison") {
    let metric = HealthMetric(id: "weight", name: "Weight", value: 73.8, unit: "kg", change: nil,
                              date: .now, category: .weight)
    TodayMetricCard(data: VitalCardData(id: metric.id, category: .weight, section: .physical,
        title: "Weight", value: "73.8", unit: "kg", change: nil, changeIsPositive: nil,
        sparklineData: [], metric: metric, lastUpdated: metric.date, isStale: false))
        .padding()
}
