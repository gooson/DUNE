import SwiftUI
import Charts

/// Full detail view for unified personal records (strength + cardio) with period-based chart.
struct PersonalRecordsDetailView: View {
    let records: [ActivityPersonalRecord]
    let notice: String?
    let rewardSummary: WorkoutRewardSummary
    let rewardHistory: [WorkoutRewardEvent]
    var unlockedBadgeKeys: Set<String> = []
    var preselectedKind: ActivityPersonalRecord.Kind?
    var recentWorkouts: [WorkoutSummary] = []

    @State private var viewModel = PersonalRecordsDetailViewModel()
    @State private var shareImage: ShareableImage?
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var bestValueSize: CGFloat = 52

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: DS.Spacing.sm),
               GridItem(.flexible(), spacing: DS.Spacing.sm)]
    }

    private let cardMinHeight: CGFloat = 120

    private var recordsUpdateKey: Int {
        var hasher = Hasher()
        for record in records {
            hasher.combine(record.id)
            hasher.combine(record.value)
            hasher.combine(record.date.timeIntervalSince1970)
        }
        for workout in recentWorkouts {
            hasher.combine(workout.id)
            hasher.combine(workout.averagePace)
            hasher.combine(workout.date.timeIntervalSince1970)
        }
        return hasher.finalize()
    }

    private var rewardUpdateKey: Int {
        var hasher = Hasher()
        hasher.combine(rewardSummary)
        hasher.combine(rewardHistory)
        hasher.combine(unlockedBadgeKeys)
        return hasher.finalize()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                if viewModel.personalRecords.isEmpty {
                    emptyState
                } else {
                    if let notice, !notice.isEmpty {
                        noticeBanner(notice)
                    }

                    // Chip bar metric picker
                    if viewModel.availableKinds.count > 1 {
                        PRChipBar(
                            kinds: viewModel.availableKinds,
                            selected: Binding(
                                get: { viewModel.resolvedKind },
                                set: { viewModel.selectedKind = $0 }
                            )
                        )
                    }

                    // Current best hero
                    if let best = viewModel.currentBest {
                        currentBestCard(best)
                    }

                    // The chart owns its period controls and one shared date range.
                    // Enhanced timeline chart
                    timelineChart

                    // Reward progress section
                    if rewardSummary.totalPoints > 0 || rewardSummary.badgeCount > 0 {
                        RewardProgressSection(
                            summary: rewardSummary,
                            badgeDefinitions: viewModel.badgeDefinitions,
                            funComparisons: viewModel.funComparisons,
                            levelTier: viewModel.levelTier,
                            nextTier: viewModel.nextLevelTier,
                            levelProgress: viewModel.levelProgress
                        )
                    }

                    // All-time records grid
                    prGrid

                    // Enhanced achievement history
                    AchievementHistorySection(
                        groupedHistory: viewModel.groupedHistory
                    )
                }
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .accessibilityIdentifier("activity-personal-records-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Personal Records")
        .sheet(item: $shareImage) { shareable in
            ShareImageSheet(image: shareable.image, title: "Personal Record")
        }
        .task(id: recordsUpdateKey) {
            viewModel.load(records: records)
            viewModel.addPaceWorkouts(recentWorkouts)
            viewModel.refreshRewardDerived()
            if viewModel.selectedKind == nil {
                viewModel.selectedKind = preselectedKind ?? viewModel.availableKinds.first
            }
            if viewModel.resolvedKind == .fastestPace {
                await viewModel.loadPaceHistoryIfNeeded()
            }
        }
        .task(id: rewardUpdateKey) {
            viewModel.rewardSummary = rewardSummary
            viewModel.rewardHistory = rewardHistory
            viewModel.unlockedBadgeKeys = unlockedBadgeKeys
            viewModel.refreshRewardDerived()
        }
        .task(id: viewModel.resolvedKind) {
            guard viewModel.resolvedKind == .fastestPace else { return }
            await viewModel.loadPaceHistoryIfNeeded()
        }
    }

    // MARK: - Components

    private func noticeBanner(_ text: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(DS.Color.textSecondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func currentBestCard(_ best: ActivityPersonalRecord) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                Image(systemName: best.kind.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(palette.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .accessibilityHidden(true)
                Text("Current Best")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if best.isRecent {
                    Text("NEW")
                        .font(.caption2.bold())
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(palette.gold.opacity(0.18), in: Capsule())
                }
                Button {
                    let data = PRShareService.buildShareData(from: best)
                    if let image = PRShareService.renderShareImage(data: data, accentColor: best.kind.tintColor) {
                        shareImage = ShareableImage(image: image)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Share PR"))
                .accessibilityIdentifier("activity-personal-records-share-button")
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    bestValue(best)
                    bestUnit(best)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                        bestValue(best)
                        bestUnit(best)
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        bestValue(best)
                        bestUnit(best)
                    }
                }
            }

            if let delta = best.formattedDelta {
                Text(delta)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle((best.deltaValue ?? 0) > 0 ? palette.heroPositive : DS.Color.negative)
                    .accessibilityIdentifier("activity-personal-records-best-delta")
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(best.localizedTitle)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = best.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(best.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(palette.muted)
                    .accessibilityIdentifier("activity-personal-records-best-date")
            }
        }
        .foregroundStyle(palette.ink)
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(palette.surface)
                .overlay(alignment: .bottom) {
                    PersonalRecordHeroDune()
                        .fill(palette.gold.opacity(0.10))
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-personal-records-current-best")
    }

    private func bestValue(_ best: ActivityPersonalRecord) -> some View {
        Text(best.formattedValue)
            .font(dynamicTypeSize.isAccessibilitySize
                  ? .largeTitle.bold()
                  : .system(size: bestValueSize, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(LinearGradient(
                colors: [palette.heroHighlight, palette.heroAccent],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("activity-personal-records-best-value")
    }

    @ViewBuilder
    private func bestUnit(_ best: ActivityPersonalRecord) -> some View {
        if let unit = best.kind.unitLabel {
            Text(unit)
                .font(.title3.weight(.medium))
                .foregroundStyle(palette.muted)
                .accessibilityIdentifier("activity-personal-records-best-unit")
        }
    }

    @ViewBuilder
    private var periodPicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker(selection: $viewModel.selectedPeriod) {
                periodOptions
            } label: {
                HStack {
                    Text("Period")
                    Spacer(minLength: DS.Spacing.sm)
                    Text(viewModel.selectedPeriod.displayName)
                }
                .font(.headline)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .pickerStyle(.menu)
            .font(.headline)
            .frame(minHeight: 44)
            .accessibilityIdentifier("activity-personal-records-period-picker")
            .accessibilityValue(viewModel.selectedPeriod.displayName)
        } else {
            Picker("Period", selection: $viewModel.selectedPeriod) {
                periodOptions
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("activity-personal-records-period-picker")
        }
    }

    private var periodOptions: some View {
        ForEach(PersonalRecordsDetailViewModel.availablePeriods, id: \.self) { period in
            Text(period.displayName)
                .tag(period)
                .accessibilityIdentifier("activity-personal-records-period-\(period.rawValue)")
        }
    }

    // MARK: - Enhanced Timeline Chart

    private var timelineChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Group {
                if viewModel.resolvedKind == .fastestPace {
                    Text("Pace History")
                } else {
                    Text("PR Timeline")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DS.Color.textSecondary)

            periodPicker

            Text(chartRangeLabel)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("activity-personal-records-chart-range")

            if let unit = viewModel.resolvedKind?.unitLabel {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                    .accessibilityIdentifier("activity-personal-records-chart-unit")
            }

            if let latest = viewModel.chartData.last {
                latestRecordSummary(latest)
            }

            if viewModel.chartData.isEmpty {
                Group {
                    if viewModel.isLoadingPaceHistory && viewModel.resolvedKind == .fastestPace {
                        ProgressView()
                    } else if let error = viewModel.paceHistoryError,
                              viewModel.resolvedKind == .fastestPace {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else if viewModel.resolvedKind == .fastestPace {
                        Group {
                            if viewModel.selectedPeriod == .year {
                                Text("No pace recorded in the past year.")
                            } else {
                                Text("No pace recorded in this period. Try a longer period.")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    } else {
                        Text(String(localized: "No records in this period."))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                let chartColor = viewModel.resolvedKind?.tintColor ?? DS.Color.activity
                let chartLineColor = chartColor.opacity(0.7)
                let chartFill = LinearGradient(
                    colors: [chartColor.opacity(0.25), chartColor.opacity(0.02)],
                    startPoint: .top, endPoint: .bottom
                )

                Chart(viewModel.chartData) { record in
                    // Gradient area fill under the curve
                    AreaMark(
                        x: .value("Date", record.date),
                        y: .value("Value", record.value)
                    )
                    .foregroundStyle(chartFill)
                    .interpolationMethod(viewModel.resolvedKind == .fastestPace ? .linear : .catmullRom)

                    // Smooth curved line
                    LineMark(
                        x: .value("Date", record.date),
                        y: .value("Value", record.value)
                    )
                    .foregroundStyle(chartLineColor)
                    // A smoothed pace curve can imply a faster value than any workout measured.
                    .interpolationMethod(viewModel.resolvedKind == .fastestPace ? .linear : .catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    // Data points
                    PointMark(
                        x: .value("Date", record.date),
                        y: .value("Value", record.value)
                    )
                    .foregroundStyle(chartColor)
                    .symbolSize(isLatestPoint(record) ? 100 : 50)
                    .annotation(position: .top, spacing: 6, overflowResolution:
                                    dynamicTypeSize.isAccessibilitySize
                                    ? .init(x: .fit(to: .plot), y: .fit(to: .chart))
                                    : .automatic) {
                        if isLatestPoint(record) {
                            Text(record.formattedValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.primary)
                                .fixedSize()
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Color.surfacePrimary, in: Capsule())
                                .accessibilityHidden(true)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: viewModel.selectedPeriod.strideComponent,
                                             count: viewModel.selectedPeriod.strideCount)) { _ in
                        AxisGridLine()
                            .foregroundStyle(theme.accentColor.opacity(0.15))
                        AxisValueLabel(format: chartXFormat)
                            .foregroundStyle(theme.sandColor)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(theme.accentColor.opacity(0.15))
                        AxisValueLabel {
                            if let v = value.as(Double.self), let kind = viewModel.resolvedKind {
                                Text(chartAxisValue(v, for: kind))
                                    .foregroundStyle(theme.sandColor)
                            }
                        }
                    }
                }
                .chartXScale(domain: chartXDomain)
                .chartYScale(domain: chartYDomain)
                .padding(.top, 16)
                .frame(height: 252)
                .clipped()
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .id(viewModel.selectedPeriod)
        .transition(.opacity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-personal-records-timeline-chart")
    }

    /// The latest sample belongs to the selected chart period, independently of the all-time best.
    private func latestRecordSummary(_ record: ActivityPersonalRecord) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: record.kind.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(record.kind.tintColor)
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Latest Record")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                Text(record.formattedValue + (record.kind.unitLabel.map { " " + $0 } ?? ""))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("personal-records-timeline-latest-value")
                Text(record.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .accessibilityIdentifier("personal-records-timeline-latest-date")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(DS.Color.activity.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func isLatestPoint(_ record: ActivityPersonalRecord) -> Bool {
        record.id == viewModel.chartData.last?.id
    }

    /// Extend Y-axis 10% above max for breathing room
    private var chartYDomain: ClosedRange<Double> {
        let values = viewModel.chartData.map(\.value)
        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }
        let range = maxVal - minVal
        let padding = max(range * 0.1, 1)
        return max(0, minVal - padding)...(maxVal + padding)
    }

    private var chartXDomain: ClosedRange<Date> {
        let range = viewModel.chartDateRange
        // A midnight empty interval needs a nonzero display domain, never synthetic records.
        return range.start...max(range.end, range.start.addingTimeInterval(1))
    }

    private var chartXFormat: Date.FormatStyle {
        switch viewModel.selectedPeriod {
        case .day: .dateTime.hour()
        case .week: .dateTime.weekday(.abbreviated)
        case .month: .dateTime.day().month(.abbreviated)
        case .sixMonths, .year: .dateTime.month(.abbreviated)
        }
    }

    private enum DateFormatters {
        static let day: DateIntervalFormatter = {
            let formatter = DateIntervalFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }()
        static let range: DateIntervalFormatter = {
            let formatter = DateIntervalFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter
        }()
    }

    private var chartRangeLabel: String {
        let range = viewModel.chartDateRange
        let formatter = viewModel.selectedPeriod == .day ? DateFormatters.day : DateFormatters.range
        return formatter.string(from: range.start, to: range.end)
    }

    // MARK: - All-Time Records Grid

    private var prGrid: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let kind = viewModel.resolvedKind {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "All %@ Records"),
                        kind.displayName
                    )
                )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
            }

            if viewModel.allTimeRecords.isEmpty {
                Text(String(localized: "No records yet."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
                    ForEach(viewModel.allTimeRecords) { record in
                        prCard(record)
                    }
                }
            }
        }
    }

    private func prCard(_ record: ActivityPersonalRecord) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: record.kind.iconName)
                    .font(.caption2)
                    .foregroundStyle(record.kind.tintColor)
                Text(record.localizedTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if record.isRecent {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(DS.Color.activity, in: Capsule())
                }
            }

            if let subtitle = record.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(record.formattedValue)
                    .font(DS.Typography.cardScore)
                    .foregroundStyle(theme.heroTextGradient)
                    .fixedSize(horizontal: false, vertical: true)

                if let unit = record.kind.unitLabel {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Text(record.date, style: .date)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        .padding(DS.Spacing.sm)
        .background(record.kind.tintColor.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .strokeBorder(record.kind.tintColor.opacity(0.16), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "trophy")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("No personal records yet.")
                .font(.headline)
                .foregroundStyle(DS.Color.textSecondary)
            Text("Build your workout history to track both strength and cardio PRs.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    // MARK: - Formatting

    private func chartAxisValue(_ value: Double, for kind: ActivityPersonalRecord.Kind) -> String {
        switch kind {
        case .fastestPace:
            let totalSeconds = Int(value)
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(minutes)'\(String(format: "%02d", seconds))\""
        case .longestDistance:
            return (value / 1000.0).formattedWithSeparator(fractionDigits: 1)
        case .longestDuration:
            return TimeInterval(value).formattedDuration()
        case .estimated1RM, .repMax, .strengthWeight, .sessionVolume,
             .highestCalories, .highestElevation:
            return value.formattedWithSeparator()
        }
    }
}

/// Static decoration conveys celebration without progress or continuous motion.
private struct PersonalRecordHeroDune: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.75))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.height * 0.42),
            control1: CGPoint(x: rect.width * 0.30, y: rect.height * 0.95),
            control2: CGPoint(x: rect.width * 0.70, y: rect.height * 0.15)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
