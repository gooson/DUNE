import SwiftUI
import Charts

/// Stacked bar chart showing daily exercise volume breakdown by type.
struct StackedVolumeBarChartView: View {
    let dailyBreakdown: [DailyVolumePoint]
    let topTypeKeys: [String] // Top 5 type keys for color assignment
    let typeColors: [String: Color]
    let typeNames: [String: String]

    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Daily Volume")
                .font(.subheadline.weight(.semibold))

            if dailyBreakdown.isEmpty || dailyBreakdown.allSatisfy({ $0.segments.isEmpty }) {
                emptyState
            } else {
                chartView
                    .frame(height: 160)
                    .clipped()

                legendRow
            }
        }
        .padding(DS.Spacing.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart {
            ForEach(dailyBreakdown) { day in
                ForEach(flattenedSegments(for: day), id: \.id) { segment in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Minutes", segment.minutes)
                    )
                    .foregroundStyle(colorFor(segment.typeKey))
                }
            }

            if let selectedDate, let day = dailyBreakdown.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
            }) {
                RuleMark(x: .value("Selected", day.date, unit: .day))
                    .foregroundStyle(.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let mins = value.as(Double.self) {
                    AxisValueLabel {
                        Text(mins >= 60 ? String(format: "%.0fh", mins / 60) : String(format: "%.0f", mins))
                    }
                }
                AxisGridLine()
            }
        }
        .chartYScale(domain: 0...(maxDailyMinutes * 1.15))
        .chartXSelection(value: $selectedDate)
        .sensoryFeedback(.selection, trigger: selectedDate)
        .overlay(alignment: .top) {
            if let selectedDate,
               let day = dailyBreakdown.first(where: {
                   Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
               }) {
                let totalMins = day.totalDuration / 60.0
                ChartSelectionOverlay(
                    date: day.date,
                    value: totalMins >= 60
                        ? String(format: "%.1fh", totalMins / 60)
                        : "\(totalMins.formattedWithSeparator())m",
                    dateFormat: .dateTime.month(.abbreviated).day()
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.15), value: selectedDate)
            }
        }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: DS.Spacing.md) {
            ForEach(topTypeKeys.prefix(5), id: \.self) { key in
                HStack(spacing: 4) {
                    Circle()
                        .fill(colorFor(key))
                        .frame(width: 6, height: 6)
                    Text(typeNames[key] ?? key)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Helpers

    private struct FlatSegment: Identifiable {
        let id: String
        let typeKey: String
        let minutes: Double
    }

    private func flattenedSegments(for day: DailyVolumePoint) -> [FlatSegment] {
        day.segments.map { segment in
            FlatSegment(
                id: "\(day.date.timeIntervalSince1970)-\(segment.typeKey)",
                typeKey: segment.typeKey,
                minutes: segment.duration / 60.0
            )
        }
    }

    private func colorFor(_ typeKey: String) -> Color {
        typeColors[typeKey] ?? .gray.opacity(0.5)
    }

    private var maxDailyMinutes: Double {
        let maxVal = dailyBreakdown.map { $0.totalDuration / 60.0 }.max() ?? 0
        return Swift.max(maxVal, 1)
    }

    private var xAxisStride: Int {
        let count = dailyBreakdown.count
        if count <= 7 { return 1 }
        if count <= 30 { return 7 }
        if count <= 90 { return 14 }
        return 30
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("Daily volume will appear as you exercise")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }
}
