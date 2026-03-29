import SwiftUI

/// Consolidated insights section combining non-sleep insight cards with template nudge.
/// Replaces the separate insightCardsSection and TemplateNudgeCard placement.
struct SmartInsightsSection: View {
    let insightCards: [InsightCardData]
    let templateNudge: WorkoutTemplateRecommendation?
    let onDismissInsight: (String) -> Void
    let onSaveTemplate: () -> Void
    let onDismissNudge: () -> Void

    private var hasContent: Bool {
        !insightCards.isEmpty || templateNudge != nil
    }

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                header

                // Insight cards (max 3)
                ForEach(insightCards.prefix(3)) { card in
                    InsightCardView(data: card) {
                        onDismissInsight(card.id)
                    }
                }

                // Template nudge
                if let nudge = templateNudge {
                    TemplateNudgeCard(
                        recommendation: nudge,
                        onSaveAsTemplate: onSaveTemplate,
                        onDismiss: onDismissNudge
                    )
                }
            }
            .accessibilityIdentifier("dashboard-smart-insights-section")
        }
    }

    private var header: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "lightbulb.fill")
                .font(.subheadline)
                .foregroundStyle(DS.Color.caution)

            Text("Insights")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .padding(.horizontal, DS.Spacing.xs)
    }
}
