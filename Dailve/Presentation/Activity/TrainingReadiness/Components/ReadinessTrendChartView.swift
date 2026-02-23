import SwiftUI
import Charts

/// 14-day training readiness score trend line chart.
struct ReadinessTrendChartView: View {
    let data: [ChartDataPoint]

    @State private var selectedDate: Date?

    private enum Gradients {
        static let area = LinearGradient(
            colors: [DS.Color.activity.opacity(0.15), DS.Color.activity.opacity(0.02)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Readiness Trend")
                .font(.subheadline.weight(.semibold))

            if data.isEmpty {
                Text("Not enough data to show trend.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
            } else {
                chartView
                    .frame(height: 160)
                    .clipped()
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Score", point.value)
            )
            .foregroundStyle(colorForScore(point.value))
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.5))

            AreaMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Score", point.value)
            )
            .foregroundStyle(Gradients.area)
            .interpolationMethod(.catmullRom)

            if let selected = selectedDate,
               Calendar.current.isDate(point.date, inSameDayAs: selected) {
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Score", point.value)
                )
                .foregroundStyle(colorForScore(point.value))
                .symbolSize(50)

                RuleMark(x: .value("Date", point.date, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
            }
        }
        .chartYScale(domain: 0...110)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                    }
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .sensoryFeedback(.selection, trigger: selectedDate)
        .overlay(alignment: .top) {
            if let selected = selectedDate,
               let point = data.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selected) }) {
                ChartSelectionOverlay(
                    date: point.date,
                    value: "\(Int(point.value))"
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: selectedDate)
            }
        }
    }

    // MARK: - Color

    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 80...: DS.Color.scoreExcellent
        case 60..<80: DS.Color.scoreGood
        case 40..<60: DS.Color.scoreFair
        default: DS.Color.scoreWarning
        }
    }
}
