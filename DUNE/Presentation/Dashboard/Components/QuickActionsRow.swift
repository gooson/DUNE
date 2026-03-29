import SwiftUI

struct QuickActionsRow: View {
    let onLogWeight: () -> Void
    let onOpenSleep: () -> Void
    let onOpenBriefing: () -> Void
    let onOpenHealthQA: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                quickActionButton(
                    icon: "scalemass.fill",
                    label: String(localized: "Log Weight"),
                    color: DS.Color.body,
                    identifier: "dashboard-quick-action-weight",
                    action: onLogWeight
                )

                quickActionButton(
                    icon: "bed.double.fill",
                    label: String(localized: "Sleep"),
                    color: DS.Color.sleep,
                    identifier: "dashboard-quick-action-sleep",
                    action: onOpenSleep
                )

                quickActionButton(
                    icon: "sun.horizon.fill",
                    label: String(localized: "Briefing"),
                    color: DS.Color.warmGlow,
                    identifier: "dashboard-quick-action-briefing",
                    action: onOpenBriefing
                )

                quickActionButton(
                    icon: "bubble.left.and.text.bubble.right.fill",
                    label: String(localized: "Ask AI"),
                    color: DS.Color.hrv,
                    identifier: "dashboard-quick-action-qa",
                    action: onOpenHealthQA
                )
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
        .accessibilityIdentifier("dashboard-quick-actions")
    }

    private func quickActionButton(
        icon: String,
        label: String,
        color: Color,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
