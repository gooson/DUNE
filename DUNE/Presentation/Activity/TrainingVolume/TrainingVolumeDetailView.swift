import SwiftUI
import SwiftData

/// Comprehensive training volume analysis screen.
/// Entry point: tap the training volume summary card on the Activity dashboard.
struct TrainingVolumeDetailView: View {
    @State private var viewModel = TrainingVolumeViewModel()
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var exerciseRecords: [ExerciseRecord]
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }
    private var weeklyGoalLabel: String {
        String.localizedStringWithFormat(String(localized: "Weekly goal: %lld days"), Int64(viewModel.weeklyGoal))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                periodPicker
                    .staggeredAppear(index: 0)

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
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
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
        .accessibilityIdentifier("activity-training-volume-period-picker")
        .accessibilityValue(viewModel.selectedPeriod.displayName)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ comparison: PeriodComparison) -> some View {
        currentSummary(comparison)
            .staggeredAppear(index: 1)
        previousSummary(comparison.previous)
            .staggeredAppear(index: 2)

        // Donut chart
        VolumeDonutChartView(exerciseTypes: comparison.current.exerciseTypes)
            .staggeredAppear(index: 2)

        // Stacked bar chart
        StackedVolumeBarChartView(
            dailyBreakdown: viewModel.chartDailyBreakdown,
            topTypeKeys: comparison.current.exerciseTypes.prefix(5).map(\.typeKey),
            typeColors: buildTypeColors(comparison.current.exerciseTypes),
            typeNames: buildTypeNames(comparison.current.exerciseTypes),
            period: viewModel.selectedPeriod
        )
        .staggeredAppear(index: 3)

        // Training Load
        if !viewModel.trainingLoadData.isEmpty {
            TrainingLoadChartView(
                data: viewModel.trainingLoadData,
                period: viewModel.selectedPeriod
            )
            .staggeredAppear(index: 4)
        }

        // RPE Trend
        if !viewModel.rpeTrendData.isEmpty {
            RPETrendChartView(
                data: viewModel.rpeTrendData,
                period: viewModel.selectedPeriod
            )
            .staggeredAppear(index: 5)
        }

        // Exercise type list
        exerciseTypeList(comparison.current.exerciseTypes)
            .staggeredAppear(index: 6)
    }

    // MARK: - Current and Previous Periods

    private func currentSummary(_ comparison: PeriodComparison) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            let topLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
                : AnyLayout(HStackLayout(alignment: .center, spacing: DS.Spacing.lg))
            topLayout {
                if viewModel.selectedPeriod == .week && !dynamicTypeSize.isAccessibilitySize {
                    LabeledActivityRingView(
                        progress: viewModel.weeklyGoal > 0
                            ? Double(comparison.current.activeDays) / Double(viewModel.weeklyGoal)
                            : 0,
                        ringColor: palette.heroHighlight,
                        lineWidth: 8,
                        size: 88
                    ) {
                        VStack(spacing: 2) {
                            Text("\(comparison.current.activeDays)")
                                .font(.title3.bold())
                                .foregroundStyle(palette.ink)
                            Text("/ \(viewModel.weeklyGoal)")
                                .font(.caption2)
                                .foregroundStyle(palette.muted)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: "\(viewModel.selectedPeriod.displayName), \(String(localized: "Active Days"))"))
                    .accessibilityValue("\(comparison.current.activeDays)")
                    .accessibilityIdentifier("activity-training-volume-current-active-days")
                } else {
                    Text("\(comparison.current.activeDays)")
                        .font(DS.Typography.heroScore)
                        .monospacedDigit()
                        .foregroundStyle(palette.ink)
                        .accessibilityLabel(Text(verbatim: "\(viewModel.selectedPeriod.displayName), \(String(localized: "Active Days"))"))
                        .accessibilityValue("\(comparison.current.activeDays)")
                        .accessibilityIdentifier("activity-training-volume-current-active-days")
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(viewModel.selectedPeriod.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.muted)
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "calendar")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DS.Color.activity)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text("Active Days")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(palette.ink)
                    }
                    Text(weeklyGoalLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(palette.ink.opacity(0.11), in: Capsule())
                        .accessibilityIdentifier("activity-training-volume-weekly-goal-reference")
                    ChangeBadge(change: comparison.activeDaysChange, foregroundColor: palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().overlay(palette.border)
            currentMetricRow(label: "Duration", icon: "timer", iconColor: DS.Color.fitness, value: comparison.current.totalDuration.formattedDuration(),
                             change: comparison.durationChange)
            currentMetricRow(label: "Calories", icon: "flame.fill", iconColor: .orange,
                             value: "\(comparison.current.totalCalories.formattedWithSeparator()) kcal",
                             change: comparison.calorieChange)
            currentMetricRow(label: "Sessions", icon: "figure.strengthtraining.traditional", iconColor: DS.Color.activity,
                             value: comparison.current.totalSessions.formattedWithSeparator,
                             change: comparison.sessionChange)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-training-volume-overview")
    }

    private func currentMetricRow(label: LocalizedStringKey, icon: String, iconColor: Color, value: String, change: Double?) -> some View {
        let rowLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.sm))
        return rowLayout {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(palette.muted)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            ChangeBadge(change: change, foregroundColor: palette.ink)
        }
    }

    private func previousSummary(_ previous: VolumePeriodSummary?) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Previous")
                    .font(DS.Typography.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
                if let previous {
                    Text(verbatim: "\(previous.startDate.formatted(date: .abbreviated, time: .omitted)) – \(previous.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("activity-training-volume-previous-period")
                    previousMetricRow(label: "Active Days", icon: "calendar", iconColor: DS.Color.activity,
                                      value: previous.activeDays.formattedWithSeparator,
                                      identifier: "active-days")
                    previousMetricRow(label: "Duration", icon: "timer", iconColor: DS.Color.fitness,
                                      value: previous.totalDuration.formattedDuration(),
                                      identifier: "duration")
                    previousMetricRow(label: "Calories", icon: "flame.fill", iconColor: .orange,
                                      value: "\(previous.totalCalories.formattedWithSeparator()) kcal",
                                      identifier: "calories")
                    previousMetricRow(label: "Sessions", icon: "figure.strengthtraining.traditional", iconColor: DS.Color.activity,
                                      value: previous.totalSessions.formattedWithSeparator,
                                      identifier: "sessions")
                } else {
                    Text("No Data")
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-training-volume-previous-comparison")
    }

    private func previousMetricRow(label: LocalizedStringKey, icon: String, iconColor: Color, value: String, identifier: String) -> some View {
        let rowLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.sm))
        return rowLayout {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("activity-training-volume-previous-value-\(identifier)")
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
            .accessibilityIdentifier("activity-training-volume-type-list")
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
