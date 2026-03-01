import SwiftUI
import Charts

/// Compact training volume card for the Activity dashboard.
/// Shows 28-day training load bar chart + last workout metrics.
/// Tapping navigates to TrainingVolumeDetailView.
struct TrainingVolumeSummaryCard: View {
    let trainingLoadData: [TrainingLoadDataPoint]
    let lastWorkoutMinutes: Double
    let lastWorkoutCalories: Double

    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationLink(value: TrainingVolumeDestination.overview) {
            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    metricsRow
                    miniBarChart
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Last Workout Metrics

    private var metricsRow: some View {
        HStack(spacing: DS.Spacing.lg) {
            metricItem(
                icon: "flame.fill",
                value: lastWorkoutCalories > 0 ? lastWorkoutCalories.formattedWithSeparator() : "—",
                unit: "kcal"
            )
            metricItem(
                icon: "clock.fill",
                value: lastWorkoutMinutes > 0 ? lastWorkoutMinutes.formattedWithSeparator() : "—",
                unit: "min"
            )
        }
    }

    private func metricItem(icon: String, value: String, unit: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(theme.accentColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.heroTextGradient)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
    }

    // MARK: - Mini Bar Chart (28-day training load)

    private var miniBarChart: some View {
        Chart(trainingLoadData) { point in
            BarMark(
                x: .value("Day", point.date, unit: .day),
                y: .value("Load", point.load)
            )
            .foregroundStyle(theme.accentColor.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.day())
                    .foregroundStyle(theme.sandColor)
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...Swift.max((trainingLoadData.map(\.load).max() ?? 0) * 1.15, 1))
        .frame(height: 50)
        .clipped()
    }
}

#Preview {
    NavigationStack {
        TrainingVolumeSummaryCard(
            trainingLoadData: (0..<28).map { offset in
                TrainingLoadDataPoint(
                    date: Calendar.current.date(byAdding: .day, value: -offset, to: Date())!,
                    load: Double.random(in: 0...200),
                    source: nil
                )
            },
            lastWorkoutMinutes: 45,
            lastWorkoutCalories: 320
        )
        .padding()
    }
}
