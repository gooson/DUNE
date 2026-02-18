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
                    current: formatDuration(comparison.current.totalDuration),
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

    private func comparisonItem(label: String, current: String, change: Double?) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(current)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            changeBadge(change)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func changeBadge(_ change: Double?) -> some View {
        if let change {
            let isPositive = change >= 0
            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text(String(format: "%.0f%%", abs(change)))
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
            }
            .foregroundStyle(isPositive ? DS.Color.positive : DS.Color.negative)
        } else {
            Text("— No previous data")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3600
        let mins = seconds / 60
        if hours >= 1 {
            return String(format: "%.1fh", hours)
        }
        return String(format: "%.0fm", mins)
    }
}
