import SwiftUI
import Charts

/// Recent workout-day totals and a separate 28-day training-load trend.
struct TrainingVolumeSummaryCard: View {
    let trainingLoadData: [TrainingLoadDataPoint]
    let lastWorkoutMinutes: Double
    let lastWorkoutCalories: Double
    let recentWorkoutDate: Date?

    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var chartHeight: CGFloat = 70

    init(
        trainingLoadData: [TrainingLoadDataPoint],
        lastWorkoutMinutes: Double,
        lastWorkoutCalories: Double,
        recentWorkoutDate: Date? = nil
    ) {
        self.trainingLoadData = trainingLoadData
        self.lastWorkoutMinutes = lastWorkoutMinutes
        self.lastWorkoutCalories = lastWorkoutCalories
        self.recentWorkoutDate = recentWorkoutDate
    }

    var body: some View {
        NavigationLink(value: TrainingVolumeDestination.overview) {
            StandardCard {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    if let recentWorkoutDate {
                        Text("Recent workout day · \(recentWorkoutDate.formatted(date: .abbreviated, time: .omitted)) total")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    } else {
                        Text("Recent workout day total")
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                    metricsRow
                    Divider()
                    Text("28-day training load")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.Color.textSecondary)
                    miniBarChart
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CardNavigationButtonStyle())
        .accessibilityIdentifier("activity-section-volume-content")
    }

    private var metricsRow: some View {
        ViewThatFits(in: .horizontal) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: DS.Spacing.sm) {
                    metricItem(icon: "timer", title: "Workout Time", value: lastWorkoutMinutes > 0 ? lastWorkoutMinutes.formattedWithSeparator() : "—", unit: "min", tint: DS.Color.activityCardio)
                    metricItem(icon: "flame.fill", title: "Calories Burned", value: lastWorkoutCalories > 0 ? lastWorkoutCalories.formattedWithSeparator() : "—", unit: "kcal", tint: DS.Color.desertBronze)
                }
            }
            VStack(spacing: DS.Spacing.sm) {
                metricItem(icon: "timer", title: "Workout Time", value: lastWorkoutMinutes > 0 ? lastWorkoutMinutes.formattedWithSeparator() : "—", unit: "min", tint: DS.Color.activityCardio)
                metricItem(icon: "flame.fill", title: "Calories Burned", value: lastWorkoutCalories > 0 ? lastWorkoutCalories.formattedWithSeparator() : "—", unit: "kcal", tint: DS.Color.desertBronze)
            }
        }
    }

    private func metricItem(icon: String, title: LocalizedStringKey, value: String, unit: LocalizedStringKey, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(value)
                    .font(DS.Typography.cardScore)
                    .monospacedDigit()
                    .foregroundStyle(theme.heroTextGradient)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(tint.opacity(0.30), lineWidth: 1)
        }
    }

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
            AxisMarks(values: .stride(by: .day, count: dynamicTypeSize.isAccessibilitySize ? 14 : 7)) { _ in
                AxisValueLabel(format: .dateTime.day())
                    .font(.caption2)
                    .foregroundStyle(theme.sandColor)
            }
        }
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...Swift.max((trainingLoadData.map(\.load).max() ?? 0) * 1.15, 1))
        .frame(height: chartHeight)
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
            recentWorkoutDate: .now
        )
        .padding()
    }
}
