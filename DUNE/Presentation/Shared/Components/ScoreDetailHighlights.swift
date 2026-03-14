import SwiftUI

/// Shared highlights section for score detail views (best day, lowest day, trends).
/// Used by Condition, Training Readiness, and Wellness score detail views.
struct ScoreDetailHighlights: View {
    let highlights: [Highlight]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Highlights")
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(highlights) { highlight in
                InlineCard {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: iconName(highlight.type))
                            .foregroundStyle(iconColor(highlight.type))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(highlight.label)
                                .font(.caption)
                                .foregroundStyle(DS.Color.textSecondary)
                            Text(highlight.value.formattedWithSeparator())
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Spacer()

                        Text(highlight.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func iconName(_ type: Highlight.HighlightType) -> String {
        switch type {
        case .high:  "arrow.up.circle.fill"
        case .low:   "arrow.down.circle.fill"
        case .trend: "chart.line.uptrend.xyaxis"
        }
    }

    private func iconColor(_ type: Highlight.HighlightType) -> Color {
        switch type {
        case .high:  DS.Color.positive
        case .low:   DS.Color.caution
        case .trend: DS.Color.hrv
        }
    }
}
