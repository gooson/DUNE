import SwiftUI
import SwiftData
import Charts

/// Detail view for a single exercise type's training volume.
/// Shows trend chart, period comparison, and recent sessions.
struct ExerciseTypeDetailView: View {
    let typeKey: String
    let displayName: String

    @State private var viewModel: ExerciseTypeDetailViewModel
    @Query(sort: \ExerciseRecord.date, order: .reverse) private var exerciseRecords: [ExerciseRecord]

    @State private var selectedDate: Date?

    init(typeKey: String, displayName: String) {
        self.typeKey = typeKey
        self.displayName = displayName
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
        }
        .background { DetailWaveBackground() }
        .navigationTitle(displayName)
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

    // MARK: - Header Card

    private var headerCard: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Icon badge
            iconBadge

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                if let summary = viewModel.currentSummary {
                    statItem(
                        label: "Duration",
                        value: summary.totalDuration.formattedDuration()
                    )
                    statItem(
                        label: "Calories",
                        value: "\(summary.totalCalories.formattedWithSeparator()) kcal"
                    )
                    statItem(
                        label: "Sessions",
                        value: summary.sessionCount.formattedWithSeparator
                    )
                } else {
                    Text("No data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private var iconBadge: some View {
        let color = resolveColor()
        let icon = resolveIcon()
        return Image(systemName: icon)
            .font(.title)
            .foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: DS.Radius.md))
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
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .chartYScale(domain: 0...(maxTrendMinutes * 1.15))
            .chartXSelection(value: $selectedDate)
            .sensoryFeedback(.selection, trigger: selectedDate)
            .frame(height: 180)
            .clipped()
            .overlay(alignment: .top) {
                if let point = selectedTrendPoint {
                    ChartSelectionOverlay(
                        date: point.date,
                        value: "\(point.value.formattedWithSeparator())m",
                        dateFormat: .dateTime.month(.abbreviated).day()
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: selectedDate)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Period Comparison

    private func comparisonCard(_ current: ExerciseTypeVolume) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Period Comparison")
                .font(.subheadline.weight(.semibold))

            let columns = [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                comparisonItem(
                    label: "Duration",
                    current: current.totalDuration.formattedDuration(),
                    change: viewModel.durationChange
                )
                comparisonItem(
                    label: "Calories",
                    current: "\(current.totalCalories.formattedWithSeparator()) kcal",
                    change: viewModel.calorieChange
                )
                comparisonItem(
                    label: "Sessions",
                    current: current.sessionCount.formattedWithSeparator,
                    change: nil
                )
                if let distance = current.totalDistance, distance > 0 {
                    comparisonItem(
                        label: "Distance",
                        current: formatDistance(distance),
                        change: nil
                    )
                }
                if let volume = current.totalVolume, volume > 0 {
                    comparisonItem(
                        label: "Volume",
                        current: formatVolume(volume),
                        change: nil
                    )
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func comparisonItem(label: String, current: String, change: Double?) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(current)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            ChangeBadge(change: change)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .foregroundStyle(.secondary)
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

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
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

    private func resolveColor() -> Color {
        if let actType = WorkoutActivityType(rawValue: typeKey) {
            return actType.color
        }
        return DS.Color.activity
    }

    private func resolveIcon() -> String {
        if let actType = WorkoutActivityType(rawValue: typeKey) {
            return actType.iconName
        }
        return "dumbbell.fill"
    }
}
