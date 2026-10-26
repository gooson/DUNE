import SwiftUI

/// 2-column grid of unified personal records (strength + cardio).
struct PersonalRecordsSection: View {
    let records: [ActivityPersonalRecord]
    let notice: String?
    let rewardSummary: WorkoutRewardSummary?

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: DS.Spacing.sm),
         GridItem(.flexible(), spacing: DS.Spacing.sm)]
    }

    var body: some View {
        if records.isEmpty {
            emptyState
        } else {
            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    if let rewardSummary, rewardSummary.totalPoints > 0 || rewardSummary.badgeCount > 0 {
                        rewardSummaryRow(rewardSummary)
                    }

                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: DS.Spacing.sm) {
                            ForEach(records.prefix(8)) { record in
                                prCard(record)
                            }
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                            ForEach(records.prefix(8)) { record in
                                prCard(record)
                            }
                        }
                    }

                    if let notice, !notice.isEmpty {
                        Text(notice)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func rewardSummaryRow(_ summary: WorkoutRewardSummary) -> some View {
        ActivityMetricsLayout(horizontalSpacing: DS.Spacing.sm, verticalSpacing: DS.Spacing.xs) {
            rewardSummaryItems(summary)
        }
    }

    @ViewBuilder
    private func rewardSummaryItems(_ summary: WorkoutRewardSummary) -> some View {
            Label(
                String.localizedStringWithFormat(
                    String(localized: "Lv %@"),
                    summary.level.formattedWithSeparator
                ),
                systemImage: "star.circle.fill"
            )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DS.Color.desertBronze, in: Capsule())

            Label(
                String.localizedStringWithFormat(
                    String(localized: "%@ badges"),
                    summary.badgeCount.formattedWithSeparator
                ),
                systemImage: "medal.fill"
            )
                .font(.caption2)
                .foregroundStyle(DS.Color.desertBronze)

            Text(
                String.localizedStringWithFormat(
                    String(localized: "%@ pts"),
                    summary.totalPoints.formattedWithSeparator
                )
            )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DS.Color.desertBronze)
    }

    private func prCard(_ record: ActivityPersonalRecord) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: record.kind.isStrengthKind ? "trophy.fill" : "medal.fill")
                    .font(.headline)
                    .foregroundStyle(DS.Color.desertBronze)
                    .frame(width: 38, height: 38)
                    .background(DS.Color.activityCardio.opacity(0.22), in: Circle())
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                if record.isRecent {
                    Text("NEW BEST")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DS.Color.desertBronze)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(record.localizedTitle)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(record.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .bottom, spacing: DS.Spacing.xs) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                        Text(primaryValueText(for: record))
                            .font(DS.Typography.cardScore)
                            .foregroundStyle(theme.heroTextGradient)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        if let unit = unitText(for: record) {
                            Text(unit)
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                    if let delta = record.formattedDelta {
                        Text(delta)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle((record.deltaValue ?? 0) > 0 ? DS.Color.positive : DS.Color.negative)
                    }
                }
                Spacer(minLength: 0)
                let sparkData = sparklineData(for: record)
                if sparkData.count >= 2 {
                    NavigationLink(value: ActivityDetailDestination.personalRecords(preselectedKind: record.kind)) {
                        MiniSparklineView(dataPoints: sparkData, color: record.kind.tintColor)
                            .frame(width: 48, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String.localizedStringWithFormat(
                            String(localized: "View %@ details"),
                            record.kind.displayName
                        )
                    )
                }
            }

            Divider()
            HStack(spacing: DS.Spacing.xs) {
                Text(record.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)

                Spacer(minLength: 0)

                Image(systemName: record.source == .healthKit ? "apple.logo" : "pencil")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                    .accessibilityLabel(record.source == .healthKit ? Text("Apple Health") : Text("Manual entry"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(DS.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(.ultraThinMaterial)
                    .overlay(DS.Color.activityCardio.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(DS.Color.activityCardio.opacity(0.35), lineWidth: 1)
        }
    }

    /// Builds sparkline data from all records matching the same kind.
    private func sparklineData(for record: ActivityPersonalRecord) -> [Double] {
        let byKind = records
            .filter { $0.kind == record.kind }
            .sorted { $0.date < $1.date }
            .map(\.value)
        guard byKind.count >= 2 else { return byKind }
        return Array(byKind.suffix(min(10, max(3, byKind.count))))
    }

    private var emptyState: some View {
        StandardCard {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "trophy")
                    .font(.title3)
                    .foregroundStyle(.quaternary)
                Text("Record strength and cardio workouts to track your PRs.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
        }
    }

    private func primaryValueText(for record: ActivityPersonalRecord) -> String {
        record.formattedValue
    }

    private func unitText(for record: ActivityPersonalRecord) -> String? {
        record.kind.unitLabel
    }

}
