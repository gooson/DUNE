import SwiftUI
import Charts

/// Consolidated training volume card for the Activity dashboard.
/// Replaces the 4 separate sections (WeeklySummary, MuscleMap, TrainingLoad, Today).
/// Tapping navigates to TrainingVolumeDetailView.
struct TrainingVolumeSummaryCard: View {
    let trainingLoadData: [TrainingLoadDataPoint]
    let lastWorkoutMinutes: Double
    let lastWorkoutCalories: Double
    let activeDays: Int
    let weeklyGoal: Int

    var body: some View {
        NavigationLink(value: TrainingVolumeDestination.overview) {
            HeroCard(tintColor: DS.Color.activity) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    headerRow
                    metricsRow
                    miniBarChart
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: DS.Spacing.md) {
            ActivityRingView(
                progress: weeklyGoal > 0 ? Double(activeDays) / Double(weeklyGoal) : 0,
                ringColor: DS.Color.activity,
                lineWidth: 6,
                size: 44
            )
            .overlay {
                Text("\(activeDays)")
                    .font(.caption.bold())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Training Volume")
                    .font(.subheadline.weight(.semibold))
                Text("\(activeDays)/\(weeklyGoal) days this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
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
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
            .foregroundStyle(DS.Color.activity.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.day())
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
            lastWorkoutCalories: 320,
            activeDays: 4,
            weeklyGoal: 5
        )
        .padding()
    }
}
