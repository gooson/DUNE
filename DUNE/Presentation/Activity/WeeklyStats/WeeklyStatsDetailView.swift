import SwiftUI
import SwiftData

/// Detail view for This Week: period switching, summary stats, daily volume chart, exercise breakdown.
struct WeeklyStatsDetailView: View {
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var recentRecords: [ExerciseRecord]
    @State private var viewModel = WeeklyStatsDetailViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var refreshRevision = 0

    private var isRegular: Bool { sizeClass == .regular }

    private struct LoadInput: Equatable {
        let period: WeeklyStatsDetailViewModel.StatsPeriod
        let snapshots: [ManualExerciseSnapshot]
        let revision: Int
    }

    private var loadInput: LoadInput {
        LoadInput(period: viewModel.selectedPeriod, snapshots: recentRecords.map { record in
            ManualExerciseSnapshot(
                date: record.date,
                exerciseType: record.exerciseType,
                categoryRawValue: ActivityCategory.strength.rawValue,
                equipmentRawValue: record.resolvedEquipmentRaw,
                duration: record.duration,
                calories: record.estimatedCalories ?? record.calories ?? 0,
                totalVolume: record.totalVolume,
                healthKitWorkoutID: record.healthKitWorkoutID
            )
        }, revision: refreshRevision)
    }

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
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("activity-weeklystats-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle(viewModel.selectedPeriod.rawValue)
        .task(id: loadInput) {
            await viewModel.loadData(manualSnapshots: loadInput.snapshots)
        }
        .refreshable {
            await viewModel.loadData(manualSnapshots: loadInput.snapshots)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshRevision += 1 }
        }
        .onReceive(NotificationCenter.default.mainThreadPublisher(for: .appHealthDataDidRefresh)) { _ in
            refreshRevision += 1
        }
        .onReceive(NotificationCenter.default.mainThreadPublisher(for: .NSCalendarDayChanged)) { _ in
            refreshRevision += 1
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
            // The same five ActivityStat values now share one period-aware surface.
            if !viewModel.summaryStats.isEmpty {
                A05CurrentStatsHero(
                    periodName: viewModel.selectedPeriod.displayName,
                    stats: viewModel.summaryStats
                )
                A05PreviousComparison(
                    metrics: previousMetrics(from: comparison.previous),
                    previous: comparison.previous
                )
            }

            // Daily breakdown chart (Duration / Sessions / Volume)
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

    private func previousMetrics(from previous: VolumePeriodSummary?) -> [A05PreviousMetric] {
        guard let previous else { return [] }
        return viewModel.summaryStats.compactMap { stat in
            let value: String
            switch stat.id {
            case "volume":
                let total = previous.exerciseTypes.compactMap(\.totalVolume).reduce(0, +)
                value = total >= 0.01 ? total.formattedWithSeparator() : "—"
            case "duration":
                let minutes = previous.totalDuration / 60.0
                value = minutes > 0 ? min(minutes, 28_800).formattedWithSeparator() : "—"
            case "calories":
                value = previous.totalCalories > 0 ? previous.totalCalories.formattedWithSeparator() : "—"
            case "sessions":
                value = previous.totalSessions.formattedWithSeparator
            default:
                return nil // Active Days remains current-only.
            }
            return A05PreviousMetric(stat: stat, value: value)
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

private struct A05PreviousMetric: Identifiable {
    let stat: ActivityStat
    let value: String
    var id: String { stat.id }
}

/// A05 detail-only surface; the Activity root's WeeklyStatsGrid stays untouched.
private struct A05CurrentStatsHero: View {
    let periodName: String
    let stats: [ActivityStat]

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(periodName)
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: DS.Spacing.sm) {
                    ForEach(stats) { stat in A05CurrentStatCell(stat: stat) }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
                    ForEach(Array(stats.dropLast())) { stat in A05CurrentStatCell(stat: stat) }
                }
                if let last = stats.last { A05CurrentStatCell(stat: last) }
            }
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
        .accessibilityIdentifier("activity-weeklystats-summary-grid")
    }
}

private struct A05CurrentStatCell: View {
    let stat: ActivityStat

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: stat.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(stat.iconColor)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                Text(stat.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let valueLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.xs))
            valueLayout {
                Text(stat.value)
                    .font(DS.Typography.cardScore)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("activity-weekly-stat-value-\(stat.id)")
                if !stat.unit.isEmpty {
                    Text(stat.unit)
                        .font(.caption)
                        .foregroundStyle(palette.muted)
                        .accessibilityIdentifier("activity-weekly-stat-unit-\(stat.id)")
                }
            }
            if let change = stat.change {
                HStack(spacing: 2) {
                    Image(systemName: (stat.changeIsPositive ?? false) ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 10, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(change)
                        .accessibilityIdentifier("activity-weekly-stat-change-\(stat.id)")
                }
                .font(.caption)
                .foregroundStyle(palette.ink)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

private struct A05PreviousComparison: View {
    let metrics: [A05PreviousMetric]
    let previous: VolumePeriodSummary?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
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
                        .accessibilityIdentifier("activity-weeklystats-previous-period")
                    ForEach(metrics) { metric in
                        Divider()
                        metricRow(metric)
                    }
                } else {
                    Text("No Data")
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-weeklystats-previous-comparison")
    }

    private func metricRow(_ metric: A05PreviousMetric) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.sm))
        return layout {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: metric.stat.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(metric.stat.iconColor)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(metric.stat.title)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(metric.value)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .accessibilityIdentifier("activity-weeklystats-previous-value-\(metric.id)")
                if !metric.stat.unit.isEmpty {
                    Text(metric.stat.unit)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .accessibilityIdentifier("activity-weeklystats-previous-unit-\(metric.id)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-weeklystats-previous-\(metric.id)")
    }
}
