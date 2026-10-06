import SwiftUI

/// Weekly training statistics, with a single column at accessibility text sizes.
struct WeeklyStatsGrid: View {
    let stats: [ActivityStat]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize { return [GridItem(.flexible())] }
        return [GridItem(.flexible(), spacing: DS.Spacing.sm),
         GridItem(.flexible(), spacing: DS.Spacing.sm)]
    }

    var body: some View {
        if stats.isEmpty {
            emptyState
        } else {
            LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                ForEach(stats) { stat in
                    ActivityStatCardView(stat: stat)
                }
            }
        }
    }

    private var emptyState: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text("Complete your first workout to see stats.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }
}

// MARK: - Card View

struct ActivityStatCardView: View {
    let stat: ActivityStat

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: stat.icon)
                        .font(.caption)
                        .foregroundStyle(stat.iconColor)

                    Text(stat.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }

                // Value + change
                let valueLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.xs))
                valueLayout {
                    Text(stat.value)
                        .accessibilityIdentifier("activity-weekly-stat-value-\(stat.id)")
                        .font(DS.Typography.cardScore)
                        .foregroundStyle(theme.heroTextGradient)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if !stat.unit.isEmpty {
                        Text(stat.unit)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }

                    if let change = stat.change {
                        changeLabel(change, isPositive: stat.changeIsPositive ?? false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func changeLabel(_ change: String, isPositive: Bool) -> some View {
        HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .semibold))
            Text(change)
                .accessibilityIdentifier("activity-weekly-stat-change-\(stat.id)")
                .font(.caption2)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(isPositive ? DS.Color.positive : DS.Color.negative)
    }
}
