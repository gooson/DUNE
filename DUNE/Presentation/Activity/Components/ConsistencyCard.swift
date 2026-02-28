import SwiftUI

/// Displays workout streak and monthly consistency.
struct ConsistencyCard: View {
    let streak: WorkoutStreak?

    @Environment(\.horizontalSizeClass) private var sizeClass

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
                // Streak row
                HStack(spacing: DS.Spacing.lg) {
                    // Current streak
                    VStack(spacing: DS.Spacing.xxs) {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                            Text("\(streak.currentStreak)")
                                .font(DS.Typography.cardScore)
                                .foregroundStyle(DS.Gradient.heroText)
                            Text("days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Current Streak")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Divider().frame(height: 36)

                    // Best streak
                    VStack(spacing: DS.Spacing.xxs) {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                            Text("\(streak.bestStreak)")
                                .font(.headline)
                                .foregroundStyle(DS.Gradient.heroText)
                            Text("days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Best Streak")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 0)

                    // Chevron hint
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Monthly progress
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack {
                        Text("This Month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(streak.monthlyCount)/\(streak.monthlyGoal)")
                            .font(.caption)
                            .fontWeight(.medium)
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
                    .frame(height: 6)
                    .clipShape(Capsule())
                }
            }
        }
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
