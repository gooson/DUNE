import SwiftUI

/// Shared summary stats card for score detail views (Min/Max/Avg + change badge).
/// Used by Condition, Training Readiness, and Wellness score detail views.
struct ScoreDetailSummaryStats: View {
    let summary: MetricSummary

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Period Summary")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                HStack(spacing: DS.Spacing.lg) {
                    statItem(label: "Avg", value: summary.average.formattedWithSeparator())
                    if sizeClass == .regular { Divider().frame(height: 24) }
                    statItem(label: "Min", value: summary.min.formattedWithSeparator())
                    if sizeClass == .regular { Divider().frame(height: 24) }
                    statItem(label: "Max", value: summary.max.formattedWithSeparator())

                    if summary.changePercentage != nil {
                        Spacer()
                        ChangeBadge(change: summary.changePercentage)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statItem(label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
        }
    }
}
