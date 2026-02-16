import SwiftUI
import Charts

/// Sleep stage chart with two display modes:
/// - Day: Horizontal timeline showing stage transitions throughout the night.
/// - Week/Month+: Stacked bar chart showing daily total sleep with stage breakdown.
struct SleepStageChartView: View {
    let stages: [SleepStage]
    let dailyData: [StackedDataPoint]
    let period: TimePeriod
    var tintColor: Color = DS.Color.sleep
    @Binding var scrollPosition: Date

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220

    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if period == .day {
                dayTimelineChart
            } else {
                stackedBarChart
            }

            legend
        }
    }

    // MARK: - Day Timeline

    private var accessibilitySummary: String {
        if period == .day {
            guard !stages.isEmpty else { return "No data" }
            let totalMinutes = stages.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 60
            return "Total \(totalMinutes.hoursMinutesFormatted)"
        } else {
            guard !dailyData.isEmpty else { return "No data" }
            let avgMinutes = dailyData.map(\.total).reduce(0, +) / Double(dailyData.count) / 60
            return "Average \(avgMinutes.hoursMinutesFormatted) per night"
        }
    }

    private var dayTimelineChart: some View {
        Chart {
            ForEach(Array(stages.enumerated()), id: \.offset) { _, stage in
                BarMark(
                    xStart: .value("Start", stage.startDate),
                    xEnd: .value("End", stage.endDate),
                    y: .value("Stage", stage.stage.label)
                )
                .foregroundStyle(stageColor(stage.stage))
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel()
            }
        }
        .frame(height: chartHeight)
        .drawingGroup()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep stages timeline, \(stages.count) stages")
        .accessibilityValue(accessibilitySummary)
    }

    // MARK: - Stacked Bar Chart

    private var stackedBarChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            stackedSelectionHeader

            Chart {
                ForEach(dailyData) { dataPoint in
                    ForEach(dataPoint.segments, id: \.category) { segment in
                        BarMark(
                            x: .value("Date", dataPoint.date, unit: barXUnit),
                            y: .value("Hours", segment.value / 3600)
                        )
                        .foregroundStyle(segmentColor(segment.category))
                    }
                }

                if let point = selectedDailyPoint {
                    RuleMark(x: .value("Selected", point.date, unit: barXUnit))
                        .foregroundStyle(.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: period.visibleDomainSeconds)
            .chartScrollPosition(x: $scrollPosition)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: period.strideComponent, count: period.strideCount)) { _ in
                    AxisValueLabel(format: period.axisLabelFormat)
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                    AxisGridLine()
                }
            }
            .chartXSelection(value: $selectedDate)
            .sensoryFeedback(.selection, trigger: selectedDate)
            .frame(height: chartHeight)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sleep duration chart, \(dailyData.count) days")
            .accessibilityValue(accessibilitySummary)
        }
    }

    @ViewBuilder
    private var stackedSelectionHeader: some View {
        if let point = selectedDailyPoint {
            HStack {
                Text(point.date, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                Spacer()
                Text((point.total / 3600).hoursMinutesFormatted)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.secondary)
            .transition(.opacity)
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: DS.Spacing.lg) {
            ForEach([SleepStage.Stage.deep, .core, .rem, .awake], id: \.rawValue) { stage in
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(stageColor(stage))
                        .frame(width: 8, height: 8)
                    Text(stage.label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func stageColor(_ stage: SleepStage.Stage) -> Color {
        switch stage {
        case .deep: .indigo
        case .core: .blue
        case .rem: .cyan
        case .awake: .orange
        }
    }

    private func segmentColor(_ category: String) -> Color {
        switch category {
        case "Deep": .indigo
        case "Core": .blue
        case "REM": .cyan
        case "Awake": .orange
        default: .gray
        }
    }

    private var barXUnit: Calendar.Component {
        switch period {
        case .day:        .hour
        case .sixMonths:  .weekOfYear
        case .year:       .month
        default:          .day
        }
    }

    /// Y-axis domain with top padding to prevent clipping.
    private var yDomain: ClosedRange<Double> {
        guard let maxVal = dailyData.map(\.total).max(), maxVal > 0 else {
            return 0...12
        }
        let maxHours = maxVal / 3600
        let padding = maxHours * 0.1
        return 0...(maxHours + padding)
    }

    private var selectedDailyPoint: StackedDataPoint? {
        guard let selectedDate else { return nil }
        return dailyData.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }
}
