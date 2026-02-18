import SwiftUI
import Charts

/// 28-day training load bar chart shown on the Activity tab.
/// Each bar represents daily training load, color-coded by intensity zone.
struct TrainingLoadChartView: View {
    let data: [TrainingLoadDataPoint]

    @State private var selectedDate: Date?
    @State private var cachedMovingAverage: [ChartDataPoint] = []
    @State private var cachedWeekSummary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            HStack {
                Label("훈련량", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let summary = cachedWeekSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if data.isEmpty {
                placeholderView
            } else {
                chartView
                    .frame(height: 140)
                    .clipped()

                // Legend
                HStack(spacing: DS.Spacing.md) {
                    legendItem(color: DS.Color.positive, label: "낮음")
                    legendItem(color: DS.Color.caution, label: "보통")
                    legendItem(color: .orange, label: "높음")
                    legendItem(color: DS.Color.negative, label: "매우 높음")
                }
                .font(.caption2)
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .onAppear { recalculateChartData() }
        .onChange(of: data.count) { _, _ in recalculateChartData() }
    }

    private func recalculateChartData() {
        cachedMovingAverage = computeMovingAverage()
        cachedWeekSummary = computeWeekSummary()
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart {
            ForEach(data) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Load", point.load)
                )
                .foregroundStyle(barColor(for: point))
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }

            // 7-day moving average line
            if cachedMovingAverage.count >= 2 {
                ForEach(cachedMovingAverage) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Average", point.value),
                        series: .value("Series", "avg")
                    )
                    .foregroundStyle(DS.Color.activity.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }

            if selectedDate != nil, let point = selectedPoint {
                RuleMark(x: .value("Selected", point.date, unit: .day))
                    .foregroundStyle(.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
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
        .chartXSelection(value: $selectedDate)
        .sensoryFeedback(.selection, trigger: selectedDate)
        .overlay(alignment: .top) {
            if let point = selectedPoint {
                ChartSelectionOverlay(
                    date: point.date,
                    value: String(format: "%.1f", point.load),
                    dateFormat: .dateTime.month(.abbreviated).day()
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: selectedDate)
            }
        }
    }

    // MARK: - Helpers

    private var placeholderView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("운동 데이터가 쌓이면 훈련량을 표시합니다")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    private func barColor(for point: TrainingLoadDataPoint) -> Color {
        switch point.load {
        case ..<2:   DS.Color.positive
        case 2..<4:  DS.Color.caution
        case 4..<7:  .orange
        default:     DS.Color.negative
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).foregroundStyle(.secondary)
        }
    }

    private var selectedPoint: TrainingLoadDataPoint? {
        guard let selectedDate else { return nil }
        return data.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }

    /// 7-day rolling average
    private func computeMovingAverage() -> [ChartDataPoint] {
        guard data.count >= 7 else { return [] }
        var result: [ChartDataPoint] = []
        for i in 6..<data.count {
            let window = data[(i - 6)...i]
            let avg = window.reduce(0) { $0 + $1.load } / Double(window.count)
            guard avg.isFinite, !avg.isNaN else { continue }
            result.append(ChartDataPoint(date: data[i].date, value: avg))
        }
        return result
    }

    /// This week's total vs last week
    private func computeWeekSummary() -> String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today),
              let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today)
        else { return nil }

        let thisWeek = data.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.load }
        let lastWeek = data.filter { $0.date >= twoWeeksAgo && $0.date < weekAgo }.reduce(0) { $0 + $1.load }

        guard thisWeek > 0 else { return nil }

        if lastWeek > 0 {
            let change = ((thisWeek - lastWeek) / lastWeek) * 100
            guard change.isFinite, !change.isNaN else { return String(format: "이번 주 %.1f", thisWeek) }
            let arrow = change >= 0 ? "↑" : "↓"
            return String(format: "이번 주 %.1f (%@%.0f%%)", thisWeek, arrow, abs(change))
        }
        return String(format: "이번 주 %.1f", thisWeek)
    }
}

// MARK: - Data Point

struct TrainingLoadDataPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let load: Double
    let source: TrainingLoad.LoadSource?
}
