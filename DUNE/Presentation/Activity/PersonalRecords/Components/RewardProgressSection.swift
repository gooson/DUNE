import SwiftUI

/// Rich reward progress display with level guide, badge trophy case, and fun comparisons.
struct RewardProgressSection: View {
    let summary: WorkoutRewardSummary
    let badgeDefinitions: [WorkoutBadgeDefinition]
    let funComparisons: [FunComparison]
    let levelTier: RewardLevelTier
    let nextTier: RewardLevelTier?
    let levelProgress: (current: Int, needed: Int, fraction: Double)

    @State private var showingInfoSheet = false
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack {
                Text(String(localized: "Reward Progress"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                Spacer(minLength: 0)
                Button {
                    showingInfoSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Level progress
            levelProgressCard

            // Badge trophy case
            badgeTrophyCase

            // Fun comparisons
            if !funComparisons.isEmpty {
                funComparisonCards
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityIdentifier("activity-personal-records-reward-progress")
        .sheet(isPresented: $showingInfoSheet) {
            rewardInfoSheet
        }
    }

    // MARK: - Level Progress

    private var levelProgressCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "star.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "Level %lld — %@"),
                            Int64(summary.level),
                            levelTier.name
                        )
                    )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DS.Color.textSecondary)

                    if let next = nextTier {
                        Text(
                            String.localizedStringWithFormat(
                                String(localized: "Next: Level %lld — %@ (%lld pts to go)"),
                                Int64(next.level),
                                next.name,
                                Int64(max(0, levelProgress.needed - levelProgress.current))
                            )
                        )
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 0)

                Text(
                    String.localizedStringWithFormat(
                        String(localized: "%lld pts"),
                        Int64(summary.totalPoints)
                    )
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.activity)
            }

            ProgressView(value: levelProgress.fraction)
                .tint(DS.Color.activity)

            // Milestone tier indicators
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(RewardLevelTier.allTierMilestones, id: \.level) { milestone in
                        let isPast = summary.level >= milestone.level
                        let isCurrent = RewardLevelTier.tier(for: summary.level).name == milestone.name
                        HStack(spacing: 4) {
                            Image(systemName: isPast ? "checkmark.circle.fill" : (isCurrent ? "circle.dotted" : "circle"))
                                .font(.system(size: 10))
                                .foregroundStyle(isPast ? AnyShapeStyle(DS.Color.positive) : (isCurrent ? AnyShapeStyle(DS.Color.activity) : AnyShapeStyle(.tertiary)))
                            Text(milestone.name)
                                .font(.system(size: 10, weight: isCurrent ? .semibold : .regular))
                                .foregroundStyle(isPast ? AnyShapeStyle(DS.Color.textSecondary) : AnyShapeStyle(.tertiary))
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.sm)
        .background(DS.Color.activity.opacity(0.05), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Badge Trophy Case

    private var badgeTrophyCase: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "Badges (%lld/%lld)"),
                        Int64(badgeDefinitions.filter(\.isUnlocked).count),
                        Int64(badgeDefinitions.count)
                    )
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(badgeDefinitions) { badge in
                        badgeCard(badge)
                    }
                }
            }
        }
    }

    private func badgeCard(_ badge: WorkoutBadgeDefinition) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? badge.category.tintColor.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)

                Image(systemName: badge.isUnlocked ? badge.iconName : "lock.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(badge.isUnlocked ? AnyShapeStyle(badge.category.tintColor) : AnyShapeStyle(.quaternary))
            }

            Text(badge.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(badge.isUnlocked ? AnyShapeStyle(DS.Color.textSecondary) : AnyShapeStyle(.quaternary))
                .lineLimit(1)
        }
        .frame(width: 56)
    }

    // MARK: - Fun Comparisons

    private var funComparisonCards: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(String(localized: "This Month"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            ForEach(funComparisons) { comparison in
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: comparison.iconName)
                        .font(.title3)
                        .foregroundStyle(DS.Color.activity)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(comparison.metric)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(comparison.value.formattedWithSeparator())
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.Color.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Text(comparison.comparison)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.Color.activity)
                }
                .padding(DS.Spacing.sm)
                .background(theme.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }

    // MARK: - Info Sheet

    private var rewardInfoSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text(String(localized: "How Rewards Work"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DS.Color.textSecondary)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    infoRow(icon: "star.circle.fill", color: .yellow, title: String(localized: "Levels"), description: String(localized: "Earn points from workouts and PRs. Every 200 points advances you one level."))
                    infoRow(icon: "medal.fill", color: .orange, title: String(localized: "Badges"), description: String(localized: "Unlock badges by hitting milestones: PR counts, volume targets, workout streaks, and more."))
                    infoRow(icon: "trophy.fill", color: DS.Color.activity, title: String(localized: "Personal Records"), description: String(localized: "Set new PRs in strength (1RM, rep max, volume) and cardio (pace, distance, duration) to earn points."))
                    infoRow(icon: "flag.checkered.circle.fill", color: .mint, title: String(localized: "Milestones"), description: String(localized: "Hit workout count milestones to earn bonus points and unlock special badges."))
                }
            }
            .padding(DS.Spacing.xl)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func infoRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Badge Category Tint

extension WorkoutBadgeCategory {
    var tintColor: Color {
        switch self {
        case .prRecord: .orange
        case .volume: .purple
        case .streak: .red
        case .milestone: DS.Color.activity
        case .improvement: .green
        }
    }
}
