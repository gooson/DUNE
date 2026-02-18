import SwiftUI
import Charts

/// Heart rate timeline chart for a single workout session.
/// Shows BPM over time with area fill and avg/max annotations.
struct HeartRateChartView: View {
    let samples: [HeartRateSample]
    let averageBPM: Double
    let maxBPM: Double

    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 180

    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            headerStats

            chart
                .frame(height: chartHeight)
                .clipped()
                .overlay(alignment: .top) {
                    if let point = selectedPoint {
                        ChartSelectionOverlay(
                            date: point.date,
                            value: "\(Int(point.bpm)) bpm",
                            dateFormat: .dateTime.hour().minute()
                        )
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: selectedDate)
                    }
                }
        }
    }

    // MARK: - Header

    private var headerStats: some View {
        HStack(spacing: DS.Spacing.lg) {
            statLabel(title: "Avg", value: averageBPM > 0 ? "\(Int(averageBPM))" : "--", unit: "bpm")
            statLabel(title: "Max", value: maxBPM > 0 ? "\(Int(maxBPM))" : "--", unit: "bpm")
        }
    }

    private func statLabel(title: String, value: String, unit: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                AreaMark(
                    x: .value("Time", sample.date),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(areaGradient)
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("BPM", sample.bpm)
                )
                .foregroundStyle(DS.Color.rhr)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }

            // Average HR reference line
            if averageBPM > 0 {
                RuleMark(y: .value("Avg", averageBPM))
                    .foregroundStyle(.gray.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("avg \(Int(averageBPM))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
            }

            // Selection indicator
            if let point = selectedPoint {
                PointMark(
                    x: .value("Time", point.date),
                    y: .value("BPM", point.bpm)
                )
                .foregroundStyle(DS.Color.rhr)
                .symbolSize(48)

                RuleMark(x: .value("Selected", point.date))
                    .foregroundStyle(.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.hour().minute())
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
    }

    // MARK: - Helpers

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [DS.Color.rhr.opacity(0.3), DS.Color.rhr.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var yDomain: ClosedRange<Double> {
        let bpms = samples.map(\.bpm)
        guard let minVal = bpms.min(), let maxVal = bpms.max() else {
            return 40...200
        }
        let padding = Swift.max((maxVal - minVal) * 0.15, 10)
        return Swift.max(minVal - padding, 30)...(maxVal + padding)
    }

    private var selectedPoint: HeartRateSample? {
        guard let selectedDate else { return nil }
        return samples.min(by: {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        })
    }
}
