import SwiftUI
import SwiftData
import Charts

/// Detail view for a single exercise type's training volume.
/// Shows trend chart, period comparison, and recent sessions.
struct ExerciseTypeDetailView: View {
    let typeKey: String
    let displayName: String
    let categoryRawValue: String
    let equipmentRawValue: String?

    @State private var viewModel: ExerciseTypeDetailViewModel
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var exerciseRecords: [ExerciseRecord]

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDate: Date?
    @State private var selectionGestureState = ChartSelectionGestureState()

    init(typeKey: String, displayName: String, categoryRawValue: String = "", equipmentRawValue: String? = nil) {
        self.typeKey = typeKey
        self.displayName = displayName
        self.categoryRawValue = categoryRawValue
        self.equipmentRawValue = equipmentRawValue
        _viewModel = State(initialValue: ExerciseTypeDetailViewModel(
            typeKey: typeKey,
            displayName: displayName
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                periodPicker

                if viewModel.isLoading && viewModel.currentSummary == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    contentSection
                        .id(viewModel.selectedPeriod)
                        .transition(.opacity)
                }
            }
            .padding()
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("activity-exercise-type-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
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
        .accessibilityIdentifier("activity-exercise-type-period-picker")
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        // Header card
        headerCard

        // Trend chart
        if !viewModel.trendData.isEmpty {
            trendChart
        }

        // Period comparison
        if let current = viewModel.currentSummary {
            comparisonCard(current)
        }

        // Recent sessions
        if !viewModel.recentWorkouts.isEmpty {
            recentSessionsList
        }
    }

    // MARK: - Type Hero

    private var heroPalette: ScoreHeroPalette {
        ScoreHeroPalette(theme: theme, colorScheme: colorScheme)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                iconBadge
                Text(displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(heroPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            if let summary = viewModel.currentSummary {
                let primary = primaryMetric(for: summary)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Label(primary.label, systemImage: primary.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(heroPalette.ink)
                    Text(primary.value)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(heroPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("activity-exercise-type-primary-value")
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        supportingMetrics(summary, excluding: primary.kind)
                    }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            supportingMetrics(summary, excluding: primary.kind)
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            supportingMetrics(summary, excluding: primary.kind)
                        }
                    }
                }
            } else {
                Text("No data")
                    .font(.subheadline)
                    .foregroundStyle(heroPalette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.xl)
        .background(heroPalette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(heroPalette.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-exercise-type-hero")
    }

    private func heroMetric(_ label: LocalizedStringKey, value: String, icon: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .frame(width: 20)
                .foregroundStyle(heroPalette.ink)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(heroPalette.muted)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(heroPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum PrimaryMetricKind: Equatable {
        case volume
        case duration
        case calories
        case sessions
    }

    @ViewBuilder
    private func supportingMetrics(_ summary: ExerciseTypeVolume, excluding kind: PrimaryMetricKind) -> some View {
        if kind != .duration {
            heroMetric("Duration", value: summary.totalDuration.formattedDuration(), icon: "clock")
        }
        if kind != .calories {
            heroMetric("Calories", value: "\(summary.totalCalories.formattedWithSeparator()) kcal", icon: "flame.fill")
        }
        if kind != .sessions {
            heroMetric("Sessions", value: summary.sessionCount.formattedWithSeparator, icon: "calendar")
        }
    }

    private func primaryMetric(for summary: ExerciseTypeVolume) -> (
        kind: PrimaryMetricKind,
        label: LocalizedStringKey,
        value: String,
        icon: String
    ) {
        if let volume = summary.totalVolume, volume > 0 {
            return (.volume, "Volume", formatVolume(volume), "scalemass")
        }
        if summary.totalDuration > 0 {
            return (.duration, "Duration", summary.totalDuration.formattedDuration(), "clock")
        }
        if summary.totalCalories > 0 {
            return (.calories, "Calories", "\(summary.totalCalories.formattedWithSeparator()) kcal", "flame.fill")
        }
        return (.sessions, "Sessions", summary.sessionCount.formattedWithSeparator, "calendar")
    }

    private var iconBadge: some View {
        Group {
            if let equipment = resolvedEquipment {
                equipment.svgIcon(size: 30)
            } else {
                Image(systemName: resolveIcon())
                    .font(.system(size: 30))
            }
        }
        // The original asset or activity symbol retains its exact shape.
        // Palette ink keeps small glyph strokes legible on every opaque hero.
        .foregroundStyle(heroPalette.ink)
        .frame(width: 60, height: 60)
        .background(heroPalette.border, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(resolveColor(), lineWidth: 2)
                .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Trend Chart

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Trend")
                .font(.subheadline.weight(.semibold))

            Chart(viewModel.trendData) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Minutes", point.value)
                )
                .foregroundStyle(resolveColor().gradient)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride, count: xAxisStrideCount)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(theme.sandColor)
                    AxisGridLine()
                        .foregroundStyle(theme.accentColor.opacity(0.30))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .foregroundStyle(theme.sandColor)
                    AxisGridLine()
                        .foregroundStyle(theme.accentColor.opacity(0.30))
                }
            }
            .chartYScale(domain: 0...(maxTrendMinutes * 1.15))
            .scrollableChartSelectionOverlay(
                isScrollable: false,
                visibleDomainLength: nil,
                scrollPosition: nil,
                selectedDate: $selectedDate,
                selectionState: $selectionGestureState
            ) { proxy, plotFrame, chartSize in
                if let point = selectedTrendPoint,
                   let anchor = selectedAnchor(for: point, proxy: proxy, plotFrame: plotFrame) {
                    FloatingChartSelectionOverlay(
                        date: point.date,
                        value: "\(point.value.formattedWithSeparator())m",
                        anchor: anchor,
                        chartSize: chartSize,
                        plotFrame: plotFrame,
                        dateFormat: .dateTime.month(.abbreviated).day()
                    )
                    .transition(.opacity)
                }
            }
            .sensoryFeedback(.selection, trigger: selectedTrendPoint?.date)
            .frame(height: 180)
            .clipped()
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityIdentifier("activity-exercise-type-trend-chart")
    }

    // MARK: - Period Comparison

    private func comparisonCard(_ current: ExerciseTypeVolume) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Period Comparison")
                .font(.headline)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Previous period")
                if let range = previousDateRange {
                    let start = range.start.formatted(.dateTime.month(.abbreviated).day())
                    let end = range.end.formatted(.dateTime.month(.abbreviated).day())
                    Text(verbatim: "\(start) – \(end)")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.caption)
            .foregroundStyle(DS.Color.textSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("activity-exercise-type-previous-period")

            comparisonRow(
                label: "Duration", icon: "clock", metricID: "duration",
                current: current.totalDuration.formattedDuration(),
                previous: viewModel.previousSummary?.totalDuration.formattedDuration(),
                change: viewModel.durationChange
            )
            comparisonRow(
                label: "Calories", icon: "flame.fill", metricID: "calories",
                current: "\(current.totalCalories.formattedWithSeparator()) kcal",
                previous: viewModel.previousSummary.map {
                    "\($0.totalCalories.formattedWithSeparator()) kcal"
                },
                change: viewModel.calorieChange
            )
            comparisonRow(
                label: "Sessions", icon: "calendar", metricID: "sessions",
                current: current.sessionCount.formattedWithSeparator,
                previous: viewModel.previousSummary?.sessionCount.formattedWithSeparator,
                change: nil
            )
            if let distance = current.totalDistance, distance > 0 {
                comparisonRow(
                    label: "Distance", icon: "arrow.left.and.right", metricID: "distance",
                    current: formatDistance(distance),
                    previous: viewModel.previousSummary?.totalDistance.flatMap {
                        $0 > 0 ? formatDistance($0) : nil
                    },
                    change: nil
                )
            }
            if let volume = current.totalVolume, volume > 0 {
                comparisonRow(
                    label: "Volume", icon: "scalemass", metricID: "volume",
                    current: formatVolume(volume),
                    previous: viewModel.previousSummary?.totalVolume.flatMap {
                        $0 > 0 ? formatVolume($0) : nil
                    },
                    change: nil
                )
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-exercise-type-comparison")
    }

    private func comparisonRow(
        label: LocalizedStringKey,
        icon: String,
        metricID: String,
        current: String,
        previous: String?,
        change: Double?
    ) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .frame(width: 20)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                comparisonValues(current: current, previous: previous, change: change, metricID: metricID)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-exercise-type-comparison-row-\(metricID)")
    }

    private func comparisonValues(
        current: String,
        previous: String?,
        change: Double?,
        metricID: String
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    comparisonValue("Current", value: current, id: "activity-exercise-type-comparison-current-\(metricID)")
                    comparisonValue("Previous", value: previous ?? "—", id: "activity-exercise-type-comparison-previous-\(metricID)")
                    ChangeBadge(change: change)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.lg) {
                        comparisonValue("Current", value: current, id: "activity-exercise-type-comparison-current-\(metricID)")
                        comparisonValue("Previous", value: previous ?? "—", id: "activity-exercise-type-comparison-previous-\(metricID)")
                        ChangeBadge(change: change)
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        comparisonValue("Current", value: current, id: "activity-exercise-type-comparison-current-\(metricID)")
                        comparisonValue("Previous", value: previous ?? "—", id: "activity-exercise-type-comparison-previous-\(metricID)")
                        ChangeBadge(change: change)
                    }
                }
            }
        }
    }

    private func comparisonValue(_ label: LocalizedStringKey, value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(id)
        }
    }

    private var previousDateRange: (start: Date, end: Date)? {
        guard let currentStart = viewModel.trendData.first?.date else { return nil }
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -viewModel.selectedPeriod.days, to: currentStart),
              let end = calendar.date(byAdding: .day, value: -1, to: currentStart)
        else { return nil }
        return (start, end)
    }

    private func selectedAnchor(
        for point: ChartDataPoint,
        proxy: ChartProxy,
        plotFrame: CGRect
    ) -> CGPoint? {
        ChartSelectionInteraction.anchor(
            xPosition: proxy.position(forX: point.date),
            yPosition: proxy.position(forY: point.value),
            plotFrame: plotFrame
        )
    }

    // MARK: - Recent Sessions

    private var recentSessionsList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Recent Sessions")
                .font(.subheadline.weight(.semibold))

            ForEach(viewModel.recentWorkouts) { workout in
                NavigationLink {
                    HealthKitWorkoutDetailView(workout: workout)
                } label: {
                    recentSessionRow(workout)
                }
                .buttonStyle(.plain)

                if workout.id != viewModel.recentWorkouts.last?.id {
                    Divider()
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityIdentifier("activity-exercise-type-recent-sessions")
    }

    private func recentSessionRow(_ workout: WorkoutSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.date, format: .dateTime.month(.abbreviated).day().weekday(.wide))
                    .font(.subheadline)
                HStack(spacing: DS.Spacing.md) {
                    Label(workout.duration.formattedDuration(), systemImage: "clock")
                    if let cal = workout.calories, cal > 0 {
                        Label("\(cal.formattedWithSeparator()) kcal", systemImage: "flame.fill")
                    }
                    if let dist = workout.distance, dist > 0 {
                        Label(formatDistance(dist), systemImage: "arrow.left.and.right")
                    }
                }
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

    private var selectedTrendPoint: ChartDataPoint? {
        guard let selectedDate else { return nil }
        return viewModel.trendData.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    private var maxTrendMinutes: Double {
        let maxVal = viewModel.trendData.map(\.value).max() ?? 0
        return Swift.max(maxVal, 1)
    }

    private var xAxisStride: Calendar.Component {
        .day
    }

    private var xAxisStrideCount: Int {
        switch viewModel.selectedPeriod {
        case .week: 1
        case .month: 7
        case .threeMonths: 14
        case .sixMonths: 30
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return "\((meters / 1000).formattedWithSeparator(fractionDigits: 1)) km"
        }
        return "\(meters.formattedWithSeparator()) m"
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return "\((volume / 1000).formattedWithSeparator(fractionDigits: 1))t"
        }
        return "\(volume.formattedWithSeparator()) kg"
    }

    private var resolvedEquipment: Equipment? {
        equipmentRawValue.flatMap { Equipment(rawValue: $0) }
    }

    private func resolveColor() -> Color {
        if let actType = WorkoutActivityType(rawValue: typeKey) {
            return actType.color
        }
        // Fallback: resolve category raw value
        if let category = ActivityCategory(rawValue: categoryRawValue) {
            return category.color
        }
        return DS.Color.activityOther
    }

    private func resolveIcon() -> String {
        if let actType = WorkoutActivityType(rawValue: typeKey) {
            return actType.iconName
        }
        return "dumbbell.fill"
    }
}
