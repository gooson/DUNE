import SwiftUI
import Charts

/// Daily volume bar chart showing duration/calories per day within the selected period.
struct DailyVolumeChartView: View {
    let dailyBreakdown: [DailyVolumePoint]

    enum Metric: CaseIterable, Identifiable {
        case duration
        case sessions

        var id: Self { self }

        var displayName: String {
            switch self {
            case .duration: String(localized: "Duration")
            case .sessions: String(localized: "Sessions")
            }
        }
    }

    @Environment(\.appTheme) private var theme

    @State private var selectedMetric: Metric = .duration
    @State private var selectedDate: Date?

    private enum Gradients {
        static let bar = LinearGradient(
            colors: [DS.Color.activity, DS.Color.activity.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Daily Breakdown")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(Metric.allCases) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }

            if dailyBreakdown.isEmpty {
                Text("No workout data for this period.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                chartView
                    .frame(height: 160)
                    .clipped()
                    .id(selectedMetric)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: selectedMetric)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart(dailyBreakdown) { point in
            BarMark(
                x: .value("Date", point.date, unit: .day),
                y: .value(selectedMetric.displayName, valueFor(point))
            )
            .foregroundStyle(Gradients.bar)
            .cornerRadius(4)

            if let selected = selectedDate,
               Calendar.current.isDate(point.date, inSameDayAs: selected) {
                RuleMark(x: .value("Date", point.date, unit: .day))
                    .foregroundStyle(theme.accentColor.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisGridLine()
                    .foregroundStyle(theme.accentColor.opacity(0.30))
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    .foregroundStyle(theme.sandColor)
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
        .chartYScale(domain: 0...(maxY * 1.15))
        .chartXSelection(value: $selectedDate)
        .sensoryFeedback(.selection, trigger: selectedDate)
        .overlay(alignment: .top) {
            if let selected = selectedDate,
               let point = dailyBreakdown.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selected) }) {
                ChartSelectionOverlay(
                    date: point.date,
                    value: formattedValue(point)
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: selectedDate)
            }
        }
    }

    // MARK: - Helpers

    private func valueFor(_ point: DailyVolumePoint) -> Double {
        switch selectedMetric {
        case .duration: point.totalDuration / 60.0
        case .sessions: Double(point.segments.count)
        }
    }

    private var maxY: Double {
        let values = dailyBreakdown.map { valueFor($0) }
        return Swift.max(values.max() ?? 1, 1)
    }

    private func formattedValue(_ point: DailyVolumePoint) -> String {
        switch selectedMetric {
        case .duration:
            let mins = Int(point.totalDuration / 60.0)
            return "\(mins.formattedWithSeparator) min"
        case .sessions:
            return "\(point.segments.count) sessions"
        }
    }
}
