import SwiftUI

/// Enhanced achievement history with visual hierarchy and monthly grouping.
struct AchievementHistorySection: View {
    let groupedHistory: [(month: String, events: [WorkoutRewardEvent])]

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(String(localized: "Achievement History"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            if groupedHistory.isEmpty {
                emptyState
            } else {
                ForEach(Array(groupedHistory.enumerated()), id: \.offset) { _, group in
                    monthGroup(group)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
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
            // Event icon with kind-specific treatment
            eventIcon(event.kind)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(event.kind == .levelUp ? .subheadline.weight(.bold) : .caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)

                Text(eventDetailText(event))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(event.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if event.pointsAwarded > 0 {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "+%lld pts"),
                            Int64(event.pointsAwarded)
                        )
                    )
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(eventColor(event.kind), in: Capsule())
                }
            }
        }
        .padding(DS.Spacing.sm)
        .background {
            if event.kind == .levelUp {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(
                        LinearGradient(
                            colors: [Color.mint.opacity(0.08), Color.yellow.opacity(0.05)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            } else if event.kind == .badgeUnlocked {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(Color.yellow.opacity(0.04))
            }
        }
    }

    private func eventIcon(_ kind: WorkoutRewardEventKind) -> some View {
        let iconSize: CGFloat = kind == .levelUp ? 22 : 16

        return Image(systemName: iconName(for: kind))
            .font(.system(size: kind == .levelUp ? 14 : 11))
            .foregroundStyle(eventColor(kind))
            .frame(width: iconSize, height: iconSize)
            .background {
                if kind == .levelUp || kind == .badgeUnlocked {
                    Circle()
                        .fill(eventColor(kind).opacity(0.12))
                        .frame(width: iconSize + 6, height: iconSize + 6)
                }
            }
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
