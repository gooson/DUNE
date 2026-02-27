import SwiftUI

/// Unified workout row used in both Train (compact) and Exercise (full) tabs.
/// Single source of truth for workout list item rendering.
struct UnifiedWorkoutRow: View {
    let item: ExerciseListItem
    let style: Style

    enum Style {
        /// Train dashboard — InlineCard, compact info, weekday+time date
        case compact
        /// Exercise tab — plain row, full metrics, date-only
        case full
    }

    var body: some View {
        switch style {
        case .compact:
            InlineCard { compactContent }
                .prHighlight(item.isPersonalRecord)
        case .full:
            fullContent
        }
    }

    // MARK: - Compact (Train Dashboard)

    private var compactContent: some View {
        HStack(spacing: DS.Spacing.md) {
            activityIcon(size: 28, font: .body)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                titleRow

                HStack(spacing: DS.Spacing.sm) {
                    Text(item.date, format: .dateTime.weekday(.wide).hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let hrAvg = item.heartRateAvg {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                            Text(Int(hrAvg).formattedWithSeparator)
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.red.opacity(0.8))
                    }
                }

                if let summary = item.setSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                muscleBadges
            }

            Spacer()

            compactTrailing
        }
    }

    // MARK: - Full (Exercise Tab)

    private var fullContent: some View {
        HStack(spacing: DS.Spacing.md) {
            activityIcon(size: 32, font: .title3)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                titleRow

                if item.source == .manual, let localized = item.localizedType,
                   !localized.isEmpty, localized != item.type {
                    Text(item.type)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                metricsRow

                if item.milestoneDistance != nil || item.isPersonalRecord {
                    WorkoutBadgeView.inlineBadge(
                        milestone: item.milestoneDistance,
                        isPersonalRecord: item.isPersonalRecord
                    )
                }

                if let summary = item.setSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            fullTrailing
        }
        .prHighlight(item.isPersonalRecord)
    }

    // MARK: - Shared Sub-views

    @ViewBuilder
    private func activityIcon(size: CGFloat, font: Font) -> some View {
        if let equipment = item.equipment {
            equipment.svgIcon(size: size)
                .foregroundStyle(item.activityType.color)
                .accessibilityHidden(true)
        } else {
            Image(systemName: item.activityType.iconName)
                .font(.system(size: size * 0.75))
                .foregroundStyle(item.activityType.color)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    private var titleRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(item.displayName)
                .font(style == .compact ? .subheadline.weight(.medium) : .headline)
                .lineLimit(1)

            sourceBadge

            if style == .compact,
               item.milestoneDistance != nil || item.isPersonalRecord {
                WorkoutBadgeView.inlineBadge(
                    milestone: item.milestoneDistance,
                    isPersonalRecord: item.isPersonalRecord
                )
            }
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        if item.source == .healthKit || item.isLinkedToHealthKit {
            Image(systemName: "apple.logo")
                .font(.caption2)
                .foregroundStyle(.pink)
        }
    }

    /// Full-style metrics: duration + HR + pace + elevation
    private var metricsRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(item.formattedDuration)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()

            if let hrAvg = item.heartRateAvg {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                    Text(Int(hrAvg).formattedWithSeparator)
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.red.opacity(0.8))
                .lineLimit(1)
                .fixedSize()
            }

            if let pace = item.averagePace {
                Text(Self.formattedPace(pace))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.Color.activity)
                    .lineLimit(1)
                    .fixedSize()
            }

            if let elevation = item.elevationAscended, elevation > 0 {
                Text("↑\(Int(elevation).formattedWithSeparator)m")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.green)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    @ViewBuilder
    private var muscleBadges: some View {
        if !item.primaryMuscles.isEmpty {
            let badgeColor = item.activityType.color
            HStack(spacing: DS.Spacing.xxs) {
                ForEach(item.primaryMuscles.prefix(3), id: \.self) { muscle in
                    Text(muscle.displayName)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(badgeColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(badgeColor)
                }
            }
            .clipped()
        }
    }

    // MARK: - Trailing

    private var compactTrailing: some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
            Text(item.formattedDuration)
                .font(.subheadline)
                .fontWeight(.medium)
            if let cal = item.calories, cal > 0, cal < 5_000 {
                Text(item.source == .manual ? "~\(Int(cal).formattedWithSeparator) kcal" : "\(Int(cal).formattedWithSeparator) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fullTrailing: some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
            if let cal = item.calories, cal > 0, cal < 5_000 {
                Text("\(Int(cal).formattedWithSeparator) kcal")
                    .font(.subheadline)
            }
            Text(item.date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private static func formattedPace(_ secPerKm: Double) -> String {
        guard secPerKm.isFinite, secPerKm > 0, secPerKm < 86_400 else { return "—" }
        let totalSeconds = Int(secPerKm)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes)'\(String(format: "%02d", seconds))\"/km"
    }
}
