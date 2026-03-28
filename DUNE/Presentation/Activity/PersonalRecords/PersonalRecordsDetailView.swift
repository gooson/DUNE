import SwiftUI
import Charts

/// Full detail view for unified personal records (strength + cardio) with period-based chart.
struct PersonalRecordsDetailView: View {
    let records: [ActivityPersonalRecord]
    let notice: String?
    let rewardSummary: WorkoutRewardSummary
    let rewardHistory: [WorkoutRewardEvent]

    @State private var viewModel = PersonalRecordsDetailViewModel()
    @Environment(\.appTheme) private var theme

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: DS.Spacing.sm),
         GridItem(.flexible(), spacing: DS.Spacing.sm)]
    }

    private let cardMinHeight: CGFloat = 148

    private var recordsUpdateKey: Int {
        var hasher = Hasher()
        for record in records {
            hasher.combine(record.id)
            hasher.combine(record.value)
            hasher.combine(record.date.timeIntervalSince1970)
        }
        return hasher.finalize()
    }

    private var recentRewardHistory: [WorkoutRewardEvent] {
        Array(rewardHistory.prefix(30))
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

                    // Metric picker
                    if viewModel.availableKinds.count > 1 {
                        metricPicker
                    }

                    // Current best hero
                    if let best = viewModel.currentBest {
                        currentBestCard(best)
                    }

                    // Period picker
                    periodPicker

                    // Timeline chart
                    timelineChart

                    // Reward summary
                    if rewardSummary.totalPoints > 0 || rewardSummary.badgeCount > 0 {
                        rewardSummaryCard
                    }

                    // All-time records grid
                    prGrid

                    // Achievement history
                    achievementHistorySection
                }
            }
            .padding()
        }
        .accessibilityIdentifier("activity-personal-records-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Personal Records")
        .task(id: recordsUpdateKey) {
            viewModel.load(records: records)
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

    private var metricPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Metric")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Picker("Metric", selection: Binding(
                get: { viewModel.resolvedKind ?? viewModel.availableKinds.first },
                set: { viewModel.selectedKind = $0 }
            )) {
                ForEach(viewModel.availableKinds, id: \.self) { kind in
                    Text(kind.displayName).tag(Optional(kind))
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("activity-personal-records-metric-picker")
        }
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
                Text(primaryValueText(for: best))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.heroTextGradient)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                if let unit = unitText(for: best) {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: DS.Spacing.xs) {
                Text(best.localizedTitle)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                if let subtitle = best.subtitle {
                    Text("·")
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
                Chart(viewModel.chartData) { record in
                    LineMark(
                        x: .value("Date", record.date),
                        y: .value("Value", record.value)
                    )
                    .foregroundStyle(record.kind.tintColor.opacity(0.5))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", record.date),
                        y: .value("Value", record.value)
                    )
                    .foregroundStyle(record.kind.tintColor)
                    .symbolSize(record.isRecent ? 80 : 40)
                    .annotation(position: .top, spacing: 4) {
                        if record.isRecent {
                            Text(record.localizedTitle)
                                .font(.system(size: 8))
                                .foregroundStyle(DS.Color.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: chartXStride)) { _ in
                        AxisGridLine()
                            .foregroundStyle(theme.accentColor.opacity(0.30))
                        AxisValueLabel(format: chartXFormat)
                            .foregroundStyle(theme.sandColor)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(theme.accentColor.opacity(0.30))
                        AxisValueLabel {
                            if let v = value.as(Double.self), let kind = viewModel.resolvedKind {
                                Text(chartAxisValue(v, for: kind))
                                    .foregroundStyle(theme.sandColor)
                            }
                        }
                    }
                }
                .frame(height: 220)
                .clipped()
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .id(viewModel.selectedPeriod)
        .transition(.opacity)
        .accessibilityIdentifier("activity-personal-records-timeline-chart")
    }

    private var chartXStride: Calendar.Component {
        switch viewModel.selectedPeriod {
        case .day, .week: .day
        case .month: .weekOfMonth
        case .sixMonths: .month
        case .year: .month
        }
    }

    private var chartXFormat: Date.FormatStyle {
        switch viewModel.selectedPeriod {
        case .day, .week: .dateTime.day().month(.abbreviated)
        case .month: .dateTime.day().month(.abbreviated)
        case .sixMonths, .year: .dateTime.month(.abbreviated)
        }
    }

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

    private var rewardSummaryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(String(localized: "Reward Progress"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            HStack(spacing: DS.Spacing.sm) {
                Label(
                    String.localizedStringWithFormat(
                        String(localized: "Lv %lld"),
                        rewardSummary.level
                    ),
                    systemImage: "star.circle.fill"
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DS.Color.activity, in: Capsule())

                Label(
                    String.localizedStringWithFormat(
                        String(localized: "%lld badges"),
                        rewardSummary.badgeCount
                    ),
                    systemImage: "medal.fill"
                )
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)

                Spacer(minLength: 0)

                Text(
                    String.localizedStringWithFormat(
                        String(localized: "%lld pts"),
                        rewardSummary.totalPoints
                    )
                )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityIdentifier("activity-personal-records-reward-summary")
    }

    private var achievementHistorySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(String(localized: "Achievement History"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.textSecondary)

            if recentRewardHistory.isEmpty {
                Text(String(localized: "No reward events yet. Complete workouts and hit milestones to build your timeline."))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, DS.Spacing.xs)
            } else {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(recentRewardHistory) { event in
                        historyRow(event)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityIdentifier("activity-personal-records-achievement-history")
    }

    private func historyRow(_ event: WorkoutRewardEvent) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: iconName(for: event.kind))
                .font(.caption)
                .foregroundStyle(color(for: event.kind))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.textSecondary)
                Text(eventDetailText(event))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text(event.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if event.pointsAwarded > 0 {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "+%lld pts"),
                            event.pointsAwarded
                        )
                    )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.Color.activity)
                }
            }
        }
        .padding(.vertical, 4)
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
                Text(primaryValueText(for: record))
                    .font(DS.Typography.cardScore)
                    .foregroundStyle(theme.heroTextGradient)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if let unit = unitText(for: record) {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }

            if let context = contextText(for: record) {
                Text(context)
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
                    .lineLimit(1)
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

    private func primaryValueText(for record: ActivityPersonalRecord) -> String {
        record.formattedValue
    }

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

    private func unitText(for record: ActivityPersonalRecord) -> String? {
        record.kind.unitLabel
    }

    private func contextText(for record: ActivityPersonalRecord) -> String? {
        var parts: [String] = []
        if let avg = record.heartRateAvg, avg > 0 {
            parts.append("HR \(Int(avg).formattedWithSeparator)bpm")
        }
        if let steps = record.stepCount, steps > 0 {
            parts.append("\(Int(steps).formattedWithSeparator) steps")
        }

        var weatherParts: [String] = []
        if let condition = record.weatherCondition {
            weatherParts.append(weatherConditionLabel(for: condition))
        }
        if let temp = record.weatherTemperature, temp.isFinite {
            weatherParts.append("\(Int(temp).formattedWithSeparator)°")
        }
        if let humidity = record.weatherHumidity, humidity.isFinite, humidity >= 0 {
            weatherParts.append("Humidity \(Int(humidity).formattedWithSeparator)%")
        }
        if let isIndoor = record.isIndoor {
            weatherParts.append(isIndoor ? String(localized: "Indoor") : String(localized: "Outdoor"))
        }
        if !weatherParts.isEmpty {
            parts.append(weatherParts.joined(separator: " "))
        }

        guard !parts.isEmpty else { return nil }
        return parts.prefix(3).joined(separator: " · ")
    }

    private func iconName(for kind: WorkoutRewardEventKind) -> String {
        switch kind {
        case .milestone: "flag.checkered.circle.fill"
        case .personalRecord: "trophy.fill"
        case .badgeUnlocked: "medal.fill"
        case .levelUp: "star.circle.fill"
        }
    }

    private func color(for kind: WorkoutRewardEventKind) -> Color {
        switch kind {
        case .milestone: DS.Color.activity
        case .personalRecord: .orange
        case .badgeUnlocked: .yellow
        case .levelUp: .mint
        }
    }

    private func eventDetailText(_ event: WorkoutRewardEvent) -> String {
        guard let activityType = WorkoutActivityType(rawValue: event.activityTypeRawValue) else {
            return event.detail
        }
        if event.kind == .levelUp {
            return event.detail
        }
        return String.localizedStringWithFormat(
            String(localized: "%1$@: %2$@"),
            activityType.displayName,
            event.detail
        )
    }
}
