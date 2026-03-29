import SwiftUI
import Charts

/// Full detail view for unified personal records (strength + cardio) with period-based chart.
struct PersonalRecordsDetailView: View {
    let records: [ActivityPersonalRecord]
    let notice: String?
    let rewardSummary: WorkoutRewardSummary
    let rewardHistory: [WorkoutRewardEvent]
    var unlockedBadgeKeys: Set<String> = []

    @State private var viewModel = PersonalRecordsDetailViewModel()
    @Environment(\.appTheme) private var theme

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: DS.Spacing.sm),
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

                    // Period picker
                    periodPicker

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
            .padding()
        }
        .accessibilityIdentifier("activity-personal-records-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Personal Records")
        .task(id: recordsUpdateKey) {
            viewModel.load(records: records)
            viewModel.rewardSummary = rewardSummary
            viewModel.rewardHistory = rewardHistory
            viewModel.unlockedBadgeKeys = unlockedBadgeKeys
            viewModel.refreshRewardDerived()
            if viewModel.selectedKind == nil {
                viewModel.selectedKind = viewModel.availableKinds.first
            }
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
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: best.kind.iconName)
                    .foregroundStyle(best.kind.tintColor)
                Text(String(localized: "Current Best"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                Spacer(minLength: 0)
                if best.isRecent {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(DS.Color.activity, in: Capsule())
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(best.formattedValue)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.heroTextGradient)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if let unit = best.kind.unitLabel {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                if let delta = best.formattedDelta {
                    Text(delta)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle((best.deltaValue ?? 0) > 0 ? DS.Color.positive : DS.Color.negative)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: DS.Spacing.xs) {
                Text(best.localizedTitle)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                if let subtitle = best.subtitle {
                    Text("\u{00B7}")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                Text(best.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityIdentifier("activity-personal-records-current-best")
    }

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(PersonalRecordsDetailViewModel.availablePeriods, id: \.self) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("activity-personal-records-period-picker")
    }

    // MARK: - Enhanced Timeline Chart

    private var timelineChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("PR Timeline")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            if viewModel.chartData.isEmpty {
                Text(String(localized: "No records in this period."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                let chartColor = viewModel.resolvedKind?.tintColor ?? DS.Color.activity

                Chart(viewModel.chartData) { record in
                    // Gradient area fill under the curve
                    AreaMark(
                        x: .value("Date", record.date),
                        y: .value("Value", record.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [chartColor.opacity(0.25), chartColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    // Smooth curved line
                    LineMark(
                        x: .value("Date", record.date),
                        y: .value("Value", record.value)
                    )
                    .foregroundStyle(chartColor.opacity(0.7))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    // Data points
                    PointMark(
                        x: .value("Date", record.date),
                        y: .value("Value", record.value)
                    )
                    .foregroundStyle(chartColor)
                    .symbolSize(isLatestPoint(record) ? 100 : 50)
                    .annotation(position: .top, spacing: 6) {
                        if isLatestPoint(record) {
                            Text(record.formattedValue)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(chartColor)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: chartXStride)) { _ in
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
        .accessibilityIdentifier("activity-personal-records-timeline-chart")
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

    private var chartXStride: Calendar.Component {
        switch viewModel.selectedPeriod {
        case .day, .week: .day
        case .month: .weekOfYear
        case .sixMonths, .year: .month
        }
    }

    private var chartXFormat: Date.FormatStyle {
        switch viewModel.selectedPeriod {
        case .day, .week: .dateTime.day().month(.abbreviated)
        case .month: .dateTime.day().month(.abbreviated)
        case .sixMonths, .year: .dateTime.month(.abbreviated)
        }
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
                    .lineLimit(1)
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
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                Text(record.formattedValue)
                    .font(DS.Typography.cardScore)
                    .foregroundStyle(theme.heroTextGradient)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if let unit = record.kind.unitLabel {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Text(record.date, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, minHeight: cardMinHeight, alignment: .topLeading)
        .padding(DS.Spacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
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
