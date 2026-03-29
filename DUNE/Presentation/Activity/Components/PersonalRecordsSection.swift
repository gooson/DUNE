import SwiftUI

/// 2-column grid of unified personal records (strength + cardio).
struct PersonalRecordsSection: View {
    let records: [ActivityPersonalRecord]
    let notice: String?
    let rewardSummary: WorkoutRewardSummary?

    @Environment(\.appTheme) private var theme

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: DS.Spacing.sm),
         GridItem(.flexible(), spacing: DS.Spacing.sm)]
    }

    private let cardMinHeight: CGFloat = 120

    var body: some View {
        if records.isEmpty {
            emptyState
        } else {
            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    if let rewardSummary, rewardSummary.totalPoints > 0 || rewardSummary.badgeCount > 0 {
                        rewardSummaryRow(rewardSummary)
                    }

                    LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                        ForEach(records.prefix(8)) { record in
                            prCard(record)
                        }
                    }

                    // Chevron hint
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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
        HStack(spacing: DS.Spacing.xs) {
            Label(
                String.localizedStringWithFormat(
                    String(localized: "Lv %lld"),
                    summary.level
                ),
                systemImage: "star.circle.fill"
            )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DS.Color.activity, in: Capsule())

            Label(
                String.localizedStringWithFormat(
                    String(localized: "%lld badges"),
                    summary.badgeCount
                ),
                systemImage: "medal.fill"
            )
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)

            Spacer(minLength: 0)

            Text(
                String.localizedStringWithFormat(
                    String(localized: "%lld pts"),
                    summary.totalPoints
                )
            )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func prCard(_ record: ActivityPersonalRecord) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: record.kind.iconName)
                    .font(.caption2)
                    .foregroundStyle(record.kind.tintColor)

                Text(record.localizedTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                // Sparkline — own NavigationLink so tap navigates with Kind pre-selected
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

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(primaryValueText(for: record))
                    .font(DS.Typography.cardScore)
                    .foregroundStyle(theme.heroTextGradient)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if let unit = unitText(for: record) {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Spacer(minLength: 0)

                if let delta = record.formattedDelta {
                    Text(delta)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle((record.deltaValue ?? 0) > 0 ? DS.Color.positive : DS.Color.negative)
                } else if record.isRecent {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(DS.Color.activity, in: Capsule())
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: DS.Spacing.xxs) {
                Text(record.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)

                Image(systemName: record.source == .healthKit ? "apple.logo" : "pencil")
                    .font(.system(size: 8))
                    .foregroundStyle(.quaternary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        .padding(DS.Spacing.sm)
        .background {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(.ultraThinMaterial)
                // Kind-specific accent edge
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(record.kind.tintColor.opacity(0.05))
                UnevenRoundedRectangle(
                    topLeadingRadius: DS.Radius.sm,
                    bottomLeadingRadius: DS.Radius.sm,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                    .fill(record.kind.tintColor.opacity(0.2))
                    .frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
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
