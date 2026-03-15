import SwiftUI

/// Shared empty state for score detail chart areas.
/// Used when no data is available for the selected period.
struct ScoreDetailEmptyState: View {
    var chartHeight: CGFloat = 250
    var icon: String = "chart.bar.xaxis"
    var title: LocalizedStringKey = "No Data"
    var message: LocalizedStringKey = "No records for this period."

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(DS.Color.textSecondary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: chartHeight)
    }
}
