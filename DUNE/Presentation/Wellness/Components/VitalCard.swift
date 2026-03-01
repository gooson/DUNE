import SwiftUI

/// Unified metric card for 2-column grids (Today + Wellness).
struct VitalCard: View {
    let data: VitalCardData
    var animationIndex: Int = 0

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme

    private var isRegular: Bool { sizeClass == .regular }
    private var themeColor: Color { data.category.themeColor }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header: icon + title
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: data.category.iconName)
                        .font(.caption)
                        .foregroundStyle(themeColor)

                    Text(data.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Color.textSecondary)

                    Spacer(minLength: 0)

                    // Freshness label — always visible
                    freshnessLabel
                }

                // Value row
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(data.value)
                        .font(DS.Typography.cardScore)
                        .foregroundStyle(theme.heroTextGradient)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if !data.unit.isEmpty {
                        Text(data.unit)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Spacer(minLength: 0)

                    // Change indicator
                    if let change = data.change {
                        changeLabel(change)
                    }
                }

                // Baseline trend badge
                if let detail = data.baselineDetail {
                    BaselineTrendBadge(detail: detail, inversePolarity: data.inversePolarity)
                }

                // Sparkline
                if data.sparklineData.count >= 2 {
                    MiniSparklineView(dataPoints: data.sparklineData, color: themeColor)
                        .frame(height: isRegular ? 28 : 24)
                } else {
                    // Dashed placeholder
                    dashPlaceholder
                        .frame(height: isRegular ? 28 : 24)
                }
            }
        }
        .opacity(data.isStale ? 0.85 : 1.0)
    }

    // MARK: - Components

    @ViewBuilder
    private var freshnessLabel: some View {
        let label = Text(data.lastUpdated.freshnessLabel)
            .font(.caption2)
        if data.isStale {
            label.foregroundStyle(DS.Color.textSecondary)
        } else {
            label.foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func changeLabel(_ change: String) -> some View {
        let isPositive = data.changeIsPositive ?? false
        HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .semibold))
            Text(change)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(isPositive ? DS.Color.positive : DS.Color.negative)
    }

    private var dashPlaceholder: some View {
        GeometryReader { geo in
            Path { path in
                let y = geo.size.height / 2
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geo.size.width, y: y))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .foregroundStyle(.quaternary)
        }
        .accessibilityHidden(true)
    }
}
