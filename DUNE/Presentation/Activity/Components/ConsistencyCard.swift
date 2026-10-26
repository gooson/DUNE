import SwiftUI

/// Displays workout streak and monthly consistency.
struct ConsistencyCard: View {
    let streak: WorkoutStreak?

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let streak {
            filledContent(streak)
        } else {
            emptyState
        }
    }

    private func filledContent(_ streak: WorkoutStreak) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // The monthly goal leads the card; streaks provide supporting context.
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text("Monthly Workout Goal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                        Spacer()
                        Text("\(streak.monthlyCount)/\(streak.monthlyGoal)")
                            .font(.headline.weight(.semibold))
                            .monospacedDigit()
                    }

                    // Progress bar
                    GeometryReader { geo in
                        let fraction = CGFloat(streak.monthlyPercentage)
                        Capsule()
                            .fill(DS.Color.activity.opacity(0.15))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(DS.Color.activity)
                                    .frame(width: geo.size.width * fraction)
                            }
                    }
                    .frame(height: 10)
                    .clipShape(Capsule())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Monthly Workout Goal")
                    .accessibilityValue("\(streak.monthlyCount) of \(streak.monthlyGoal) days")
                }

                Divider()

                ActivityMetricsLayout(horizontalSpacing: DS.Spacing.lg, verticalSpacing: DS.Spacing.md, alignment: .top) {
                    streakMetric(value: streak.currentStreak, title: "Current Streak")
                    Divider().frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 52)
                    streakMetric(value: streak.bestStreak, title: "Best Streak")
                }
            }
        }
    }

    private func streakMetric(value: Int, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(value.formatted())
                    .font(DS.Typography.cardScore)
                    .foregroundStyle(theme.heroTextGradient)
                    .monospacedDigit()
                Text("days")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "flame")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text("Work out regularly to build a streak.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }
}
