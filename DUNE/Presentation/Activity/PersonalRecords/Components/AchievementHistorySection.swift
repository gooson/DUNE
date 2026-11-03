import SwiftUI

/// Enhanced achievement history with visual hierarchy and monthly grouping.
struct AchievementHistorySection: View {
    let groupedHistory: [(month: String, events: [WorkoutRewardEvent])]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(String(localized: "Achievement History"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            if groupedHistory.isEmpty {
                emptyState
            } else {
                ForEach(groupedHistory, id: \.month) { group in
                    monthGroup(group)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-personal-records-achievement-history")
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(.quaternary)
            Text(String(localized: "Complete workouts and hit milestones to build your timeline."))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("activity-personal-records-history-empty")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
    }

    private func monthGroup(_ group: (month: String, events: [WorkoutRewardEvent])) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(group.month)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

            ForEach(group.events) { event in
                eventRow(event)
            }
        }
    }

    private func eventRow(_ event: WorkoutRewardEvent) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            eventIcon(event.kind)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(event.title)
                    .accessibilityIdentifier("activity-personal-records-achievement-title-\(event.id)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(eventDetailText(event))
                    .accessibilityIdentifier("activity-personal-records-achievement-detail-\(event.id)")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(event.date, style: .date)
                    .accessibilityIdentifier("activity-personal-records-achievement-date-\(event.id)")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                if event.pointsAwarded > 0 {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "+%lld pts"),
                            Int64(event.pointsAwarded)
                        )
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(eventColor(event.kind).opacity(0.15), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(eventColor(event.kind).opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(eventColor(event.kind).opacity(0.22), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-personal-records-achievement-\(event.id)")
    }

    private func eventIcon(_ kind: WorkoutRewardEventKind) -> some View {
        Image(systemName: iconName(for: kind))
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(eventColor(kind))
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(eventColor(kind).opacity(0.15))
                    .overlay(Circle().stroke(eventColor(kind).opacity(0.35), lineWidth: 1))
            }
            .accessibilityHidden(true)
    }

    private func iconName(for kind: WorkoutRewardEventKind) -> String {
        switch kind {
        case .milestone: "flag.checkered.circle.fill"
        case .personalRecord: "trophy.fill"
        case .badgeUnlocked: "medal.fill"
        case .levelUp: "star.circle.fill"
        }
    }

    private func eventColor(_ kind: WorkoutRewardEventKind) -> Color {
        switch kind {
        case .milestone: DS.Color.activity
        case .personalRecord: .orange
        case .badgeUnlocked: .yellow
        case .levelUp: .mint
        }
    }

    private func eventDetailText(_ event: WorkoutRewardEvent) -> String {
        guard let activityType = WorkoutActivityType(rawValue: event.activityTypeRawValue) else {
            return event.detail
        }
        if event.kind == .levelUp {
            return event.detail
        }
        return String.localizedStringWithFormat(
            String(localized: "%1$@: %2$@"),
            activityType.displayName,
            event.detail
        )
    }
}
