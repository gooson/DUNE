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
    @Environment(\.colorScheme) private var colorScheme

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

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
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(DS.Color.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "How Rewards Work"))
                .accessibilityIdentifier("activity-personal-records-reward-info")
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(palette.heroHighlight)
                    .frame(width: 52, height: 52)
                    .background {
                        Circle()
                            .fill(palette.heroAccent.opacity(0.18))
                            .overlay(Circle().stroke(palette.heroAccent.opacity(0.7), lineWidth: 1))
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "Level %lld — %@"),
                            Int64(summary.level),
                            levelTier.name
                        )
                    )
                    .font(.headline)
                    .accessibilityIdentifier("activity-personal-records-reward-level")
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "%lld pts"),
                            Int64(summary.totalPoints)
                        )
                    )
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("activity-personal-records-reward-points")
                    .foregroundStyle(palette.heroHighlight)
                }
                Spacer(minLength: 0)
            }

            if let next = nextTier {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "Next: Level %lld — %@ (%lld pts to go)"),
                        Int64(next.level),
                        next.name,
                        Int64(max(0, levelProgress.needed - levelProgress.current))
                    )
                )
                .font(.caption)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            }

            ProgressView(value: levelProgress.fraction)
                .accessibilityIdentifier("activity-personal-records-level-progress")
                .tint(palette.heroAccent)
                .accessibilityLabel(String(localized: "Level progress"))
                .accessibilityValue(
                    String.localizedStringWithFormat(
                        String(localized: "%lld of %lld points"),
                        Int64(levelProgress.current),
                        Int64(levelProgress.needed)
                    )
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(RewardLevelTier.allTierMilestones, id: \.level) { milestone in
                        let isPast = summary.level >= milestone.level
                        let isCurrent = RewardLevelTier.tier(for: summary.level).name == milestone.name
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: isPast ? "checkmark.circle.fill" : (isCurrent ? "circle.dotted" : "circle"))
                                .foregroundStyle(isPast || isCurrent ? palette.heroAccent : palette.muted)
                            Text(milestone.name)
                                .font(.caption.weight(isCurrent ? .semibold : .regular))
                                .foregroundStyle(palette.ink)
                        }
                        .padding(.vertical, DS.Spacing.xs)
                        .padding(.horizontal, DS.Spacing.sm)
                        .background(palette.ink.opacity(0.08), in: Capsule())
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(palette.border, lineWidth: 1))
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
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: badge.isUnlocked ? badge.iconName : "lock.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(badge.isUnlocked ? AnyShapeStyle(badge.category.tintColor) : AnyShapeStyle(DS.Color.textSecondary))
                .frame(width: 48, height: 48)
                .background {
                    Circle()
                        .fill(badge.isUnlocked ? badge.category.tintColor.opacity(0.15) : DS.Color.textSecondary.opacity(0.1))
                }

            Text(badge.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 96, alignment: .top)
    }

    // MARK: - Fun Comparisons

    private var funComparisonCards: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(String(localized: "This Month"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            ForEach(funComparisons) { comparison in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: comparison.iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(DS.Color.activity)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(comparison.metric)
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                            Text(comparison.value.formattedWithSeparator())
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    Text(comparison.comparison)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
