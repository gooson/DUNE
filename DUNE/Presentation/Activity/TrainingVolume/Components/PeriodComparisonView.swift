import SwiftUI

/// Shows period-over-period comparison with change indicators.
struct PeriodComparisonView: View {
    let comparison: PeriodComparison

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Period Comparison")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: DS.Spacing.sm
            ) {
                comparisonItem(
                    label: "Duration",
                    current: comparison.current.totalDuration.formattedDuration(),
                    change: comparison.durationChange
                )
                comparisonItem(
                    label: "Calories",
                    current: "\(comparison.current.totalCalories.formattedWithSeparator()) kcal",
                    change: comparison.calorieChange
                )
                comparisonItem(
                    label: "Sessions",
                    current: comparison.current.totalSessions.formattedWithSeparator,
                    change: comparison.sessionChange
                )
                comparisonItem(
                    label: "Active Days",
                    current: "\(comparison.current.activeDays)",
                    change: comparison.activeDaysChange
                )
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Item

    private func comparisonItem(label: LocalizedStringKey, current: String, change: Double?) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(current)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            ChangeBadge(change: change, showNoData: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }


}
