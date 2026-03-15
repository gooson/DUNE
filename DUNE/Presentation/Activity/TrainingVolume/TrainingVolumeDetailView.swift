import SwiftUI
import SwiftData

/// Comprehensive training volume analysis screen.
/// Entry point: tap the training volume summary card on the Activity dashboard.
struct TrainingVolumeDetailView: View {
    @State private var viewModel = TrainingVolumeViewModel()
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var exerciseRecords: [ExerciseRecord]
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                periodPicker

                if viewModel.isLoading && viewModel.comparison == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let comparison = viewModel.comparison {
                    content(comparison)
                        .id(viewModel.selectedPeriod)
                        .transition(.opacity)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding()
                }
            }
            .padding()
        }
        .accessibilityIdentifier("activity-training-volume-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Training Volume")
        .navigationBarTitleDisplayMode(.large)
        .task(id: viewModel.selectedPeriod) {
            await viewModel.loadData(manualRecords: exerciseRecords)
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(VolumePeriod.allCases, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ comparison: PeriodComparison) -> some View {
        // Combined summary + comparison header
        combinedHeader(comparison)

        // Donut chart
        VolumeDonutChartView(exerciseTypes: comparison.current.exerciseTypes)

        // Stacked bar chart
        StackedVolumeBarChartView(
            dailyBreakdown: viewModel.chartDailyBreakdown,
            topTypeKeys: comparison.current.exerciseTypes.prefix(5).map(\.typeKey),
            typeColors: buildTypeColors(comparison.current.exerciseTypes),
            typeNames: buildTypeNames(comparison.current.exerciseTypes),
            period: viewModel.selectedPeriod
        )

        // Training Load
        if !viewModel.trainingLoadData.isEmpty {
            TrainingLoadChartView(
                data: viewModel.trainingLoadData,
                period: viewModel.selectedPeriod
            )
        }

        // RPE Trend
        if !viewModel.rpeTrendData.isEmpty {
            RPETrendChartView(
                data: viewModel.rpeTrendData,
                period: viewModel.selectedPeriod
            )
        }

        // Exercise type list
        exerciseTypeList(comparison.current.exerciseTypes)
    }

    // MARK: - Summary Header

    private func combinedHeader(_ comparison: PeriodComparison) -> some View {
        HStack(spacing: DS.Spacing.lg) {
            LabeledActivityRingView(
                progress: viewModel.weeklyGoal > 0
                    ? Double(comparison.current.activeDays) / Double(viewModel.weeklyGoal)
                    : 0,
                ringColor: theme.accentColor,
                lineWidth: 8,
                size: 80
            ) {
                VStack(spacing: 2) {
                    Text("\(comparison.current.activeDays)")
                        .font(.title3.bold())
                        .foregroundStyle(theme.heroTextGradient)
                    Text("/ \(viewModel.weeklyGoal)")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                statRow(
                    label: "Active Days",
                    value: "\(comparison.current.activeDays) of \(viewModel.weeklyGoal)",
                    change: comparison.activeDaysChange
                )
                statRow(
                    label: "Duration",
                    value: comparison.current.totalDuration.formattedDuration(),
                    change: comparison.durationChange
                )
                statRow(
                    label: "Calories",
                    value: "\(comparison.current.totalCalories.formattedWithSeparator()) kcal",
                    change: comparison.calorieChange
                )
                statRow(
                    label: "Sessions",
                    value: comparison.current.totalSessions.formattedWithSeparator,
                    change: comparison.sessionChange
                )
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func statRow(label: LocalizedStringKey, value: String, change: Double?) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(theme.heroTextGradient)
            ChangeBadge(change: change)
        }
    }

    // MARK: - Exercise Type List

    @ViewBuilder
    private func exerciseTypeList(_ types: [ExerciseTypeVolume]) -> some View {
        if !types.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("By Exercise Type")
                    .font(.subheadline.weight(.semibold))

                ForEach(types) { type in
                    NavigationLink {
                        ExerciseTypeDetailView(
                            typeKey: type.typeKey,
                            displayName: type.displayName,
                            categoryRawValue: type.categoryRawValue,
                            equipmentRawValue: type.equipmentRawValue
                        )
                    } label: {
                        ExerciseTypeSummaryRow(exerciseType: type)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("activity-training-volume-row-\(type.typeKey)")

                    if type.id != types.last?.id {
                        Divider()
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        }
    }

    // MARK: - Helpers


    private func buildTypeColors(_ types: [ExerciseTypeVolume]) -> [String: Color] {
        Dictionary(uniqueKeysWithValues: types.map { ($0.typeKey, $0.color) })
    }

    private func buildTypeNames(_ types: [ExerciseTypeVolume]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: types.map { ($0.typeKey, $0.displayName) })
    }
}
