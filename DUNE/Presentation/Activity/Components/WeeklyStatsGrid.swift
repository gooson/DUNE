import SwiftUI

/// Weekly training statistics displayed in a 2-column grid.
struct WeeklyStatsGrid: View {
    let stats: [ActivityStat]

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: DS.Spacing.sm),
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

                    Spacer(minLength: 0)
                }

                // Value + change
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(stat.value)
                        .font(DS.Typography.cardScore)
                        .foregroundStyle(theme.heroTextGradient)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    if !stat.unit.isEmpty {
                        Text(stat.unit)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Spacer(minLength: 0)

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
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(isPositive ? DS.Color.positive : DS.Color.negative)
    }
}
