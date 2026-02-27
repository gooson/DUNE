import SwiftUI
import SwiftData

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
        .background { DetailWaveBackground() }
        .navigationTitle(viewModel.selectedPeriod.rawValue)
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
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Content

    private func contentSection(_ comparison: PeriodComparison) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // Summary stats grid
            if !viewModel.summaryStats.isEmpty {
                summaryGrid
            }

            // Daily volume chart
            DailyVolumeChartView(dailyBreakdown: comparison.current.dailyBreakdown)
                .id(viewModel.selectedPeriod)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedPeriod)

            // Exercise type breakdown
            ExerciseTypeBreakdownView(exerciseTypes: comparison.current.exerciseTypes)
                .id(viewModel.selectedPeriod)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedPeriod)
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
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
            Text("Complete your first workout to see detailed stats and trends.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }
}
