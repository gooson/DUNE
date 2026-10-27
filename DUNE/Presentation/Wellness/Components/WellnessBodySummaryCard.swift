import SwiftUI

/// Body measurements, ordered consistently even when some metrics are missing.
struct WellnessBodySummaryCard: View {
    let cards: [VitalCardData]
    let comparisons: [HealthMetric.Category: WellnessBodyComparison]
    let onAdd: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var bodyCards: [VitalCardData] {
        let order: [HealthMetric.Category] = [.weight, .bodyFat, .leanBodyMass, .bmi]
        return order.compactMap { category in cards.first { $0.category == category } }
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                NavigationLink(value: BodyHistoryDestination()) {
                    CardNavigationHeader {
                        Label("Body Changes", systemImage: "figure.stand")
                            .font(DS.Typography.sectionTitle)
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(CardNavigationButtonStyle())
                .accessibilityIdentifier("wellness-link-bodyhistory")

                if bodyCards.isEmpty {
                    Text("No body records yet. Add a record to follow changes over time.")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: DS.Spacing.md) {
                        ForEach(bodyCards) { card in
                            metricLink(card)
                        }
                    }
                } else {
                    Grid(horizontalSpacing: DS.Spacing.md, verticalSpacing: DS.Spacing.md) {
                        GridRow {
                            metricCell(.weight)
                            metricCell(.bodyFat)
                        }
                        GridRow {
                            metricCell(.leanBodyMass)
                            metricCell(.bmi)
                        }
                    }
                }

                Button(action: onAdd) {
                    Label("Add Body Record", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(CardNavigationButtonStyle())
                .foregroundStyle(DS.Color.body)
                .accessibilityIdentifier("wellness-add-body-record")
            }
        }
    }

    @ViewBuilder
    private func metricCell(_ category: HealthMetric.Category) -> some View {
        if let card = bodyCards.first(where: { $0.category == category }) {
            metricLink(card)
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 1)
                .accessibilityHidden(true)
        }
    }

    private func metricLink(_ card: VitalCardData) -> some View {
        NavigationLink(value: card.metric) {
            WellnessMetricCard(data: card, comparison: comparisons[card.category], isBodyMetric: true)
        }
        .buttonStyle(CardNavigationButtonStyle())
        .accessibilityIdentifier("wellness-card-\(card.category.rawValue)")
    }
}

#Preview("No body records") {
    NavigationStack {
        WellnessBodySummaryCard(cards: [], comparisons: [:], onAdd: {})
            .padding()
    }
}
