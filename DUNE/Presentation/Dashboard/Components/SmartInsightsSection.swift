import SwiftUI

/// Consolidated insights section combining non-sleep insight cards with template nudge.
/// Replaces the separate insightCardsSection and TemplateNudgeCard placement.
struct SmartInsightsSection: View {
    let insightCards: [InsightCardData]
    let templateNudge: WorkoutTemplateRecommendation?
    let onDismissInsight: (String) -> Void
    let onSaveTemplate: () -> Void
    let onDismissNudge: () -> Void

    var body: some View {
        if !insightCards.isEmpty || templateNudge != nil {
            VStack(alignment: .leading, spacing: 6) {
                header

                ForEach(insightCards.prefix(3)) { card in
                    InsightCardView(data: card) {
                        onDismissInsight(card.id)
                    }
                }

                if let nudge = templateNudge {
                    TemplateNudgeCard(
                        recommendation: nudge,
                        onSaveAsTemplate: onSaveTemplate,
                        onDismiss: onDismissNudge
                    )
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("dashboard-smart-insights-section")
        }
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "lightbulb.fill")
                .font(.subheadline)
                .foregroundStyle(DS.Color.caution)

            Text("Insights")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }
}
