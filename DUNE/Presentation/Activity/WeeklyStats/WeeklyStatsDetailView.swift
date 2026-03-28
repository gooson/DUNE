import SwiftUI
import SwiftData
import Charts

/// Detail view for This Week: period switching, summary stats, daily volume chart, exercise breakdown.
struct WeeklyStatsDetailView: View {
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var recentRecords: [ExerciseRecord]
    @State private var viewModel = WeeklyStatsDetailViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                periodPicker

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = viewModel.errorMessage {
                    errorState(error)
                } else if let comparison = viewModel.comparison {
                    contentSection(comparison)
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .accessibilityIdentifier("activity-weeklystats-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle(viewModel.selectedPeriod.rawValue)
        .task(id: viewModel.selectedPeriod) {
            let snapshots = recentRecords.map { record in
                ManualExerciseSnapshot(
                    date: record.date,
                    exerciseType: record.exerciseType,
                    categoryRawValue: ActivityCategory.strength.rawValue,
                    equipmentRawValue: record.resolvedEquipmentRaw,
                    duration: record.duration,
                    calories: record.estimatedCalories ?? record.calories ?? 0,
                    totalVolume: record.totalVolume
                )
            }
            await viewModel.loadData(manualSnapshots: snapshots)
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(WeeklyStatsDetailViewModel.StatsPeriod.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("weeklystats-period-picker")
        .accessibilityValue(viewModel.selectedPeriod.rawValue)
    }

    // MARK: - Content

    private func contentSection(_ comparison: PeriodComparison) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // Summary stats grid
        if !viewModel.summaryStats.isEmpty {
            summaryGrid
                .accessibilityIdentifier("activity-weeklystats-summary-grid")
        }

            // Weight volume chart (kg)
            if viewModel.dailyWeightVolume.contains(where: { $0.volume > 0 }) {
                WeightVolumeChartView(
                    data: viewModel.dailyWeightVolume,
                    period: viewModel.selectedPeriod.volumePeriod
                )
                .id("weightVolume-\(viewModel.selectedPeriod.rawValue)")
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedPeriod)
            }

            // Daily duration chart
            DailyVolumeChartView(
                dailyBreakdown: viewModel.chartDailyBreakdown,
                period: viewModel.selectedPeriod.volumePeriod
            )
                .id(viewModel.selectedPeriod)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedPeriod)

            // Exercise type breakdown
            ExerciseTypeBreakdownView(exerciseTypes: comparison.current.exerciseTypes)
                .id(viewModel.selectedPeriod)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedPeriod)
                .accessibilityIdentifier("activity-weeklystats-breakdown")
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DS.Spacing.sm),
                GridItem(.flexible(), spacing: DS.Spacing.sm)
            ],
            spacing: DS.Spacing.sm
        ) {
            ForEach(viewModel.summaryStats) { stat in
                ActivityStatCardView(stat: stat)
            }
        }
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.quaternary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "chart.bar")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("No Workout Data")
                .font(.headline)
                .foregroundStyle(DS.Color.textSecondary)
            Text("Complete your first workout to see detailed stats and trends.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
}

// MARK: - Weight Volume Bar Chart

struct WeightVolumeChartView: View {
    let data: [DailyWeightVolumePoint]
    let period: VolumePeriod

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Volume (kg)")
                .font(.subheadline.weight(.semibold))

            Chart(data) { point in
                BarMark(
                    x: .value("Day", point.date, unit: .day),
                    y: .value("Volume", point.volume)
                )
                .foregroundStyle(theme.accentColor.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 7)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                        .foregroundStyle(theme.sandColor)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.formattedWithSeparator())
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYScale(domain: 0...max((data.map(\.volume).max() ?? 0) * 1.15, 1))
            .frame(height: 180)
            .clipped()
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
