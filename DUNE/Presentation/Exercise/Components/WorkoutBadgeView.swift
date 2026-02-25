import SwiftUI

/// Badge components for milestone achievements and personal records.
enum WorkoutBadgeView {

    /// Milestone badge (5K, 10K, Half, Marathon).
    static func milestone(_ distance: MilestoneDistance) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: distance.iconName)
                .font(.caption2)
            Text(distance.label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(distance.color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(distance.color.opacity(0.12), in: Capsule())
    }

    /// Personal record badge.
    static func personalRecord(_ type: PersonalRecordType) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text("PR")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(.orange.opacity(0.12), in: Capsule())
    }

    /// Compact inline badge for list rows — shows first milestone or PR.
    static func inlineBadge(
        milestone: MilestoneDistance?,
        isPersonalRecord: Bool
    ) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            if let milestone {
                Self.milestone(milestone)
            }
            if isPersonalRecord {
                Self.personalRecord(.fastestPace) // Generic PR badge
            }
        }
    }
}

/// ViewModifier to add a gold highlight border to PR rows.
struct PRHighlightModifier: ViewModifier {
    let isPersonalRecord: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPersonalRecord {
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1.5)
                }
            }
    }
}

extension View {
    func prHighlight(_ isPersonalRecord: Bool) -> some View {
        modifier(PRHighlightModifier(isPersonalRecord: isPersonalRecord))
    }
}
