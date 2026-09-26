import Charts
import SwiftUI

/// Uses one period and date domain, while keeping each metric's units and scale independent.
struct MetricComparisonView: View {
    let metrics: [HealthMetric]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var availableWidth: CGFloat = 0
    @State private var firstID: String
    @State private var secondID: String
    @State private var period: TimePeriod = .week
    @State private var referenceDate = Date()

    init(metrics: [HealthMetric]) {
        self.metrics = metrics
        _firstID = State(initialValue: metrics.first?.id ?? "")
        _secondID = State(initialValue: metrics.dropFirst().first?.id ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.md) {
                Picker("Period", selection: $period) {
                    ForEach(TimePeriod.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                            .accessibilityIdentifier("metric-comparison-period-\($0.rawValue)")
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("metric-comparison-period")

                Text("Same dates; separate scales. Trends do not establish cause.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let layout = availableWidth >= 760 && !dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.md))
                    : AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
                layout {
                    pane(selection: $firstID, title: "First Metric", identifier: "metric-comparison-first")
                    pane(selection: $secondID, title: "Second Metric", identifier: "metric-comparison-second")
                }
                }
                .padding(DS.Spacing.md)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
            .navigationTitle("Compare Metrics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("metric-comparison-done")
                }
            }
        }
        .presentationDetents([.large])
    }

    private func pane(selection: Binding<String>, title: LocalizedStringKey, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Picker(title, selection: selection) {
                    ForEach(metrics) { metric in
                        Text(metric.name).tag(metric.id)
                    }
                }
                .pickerStyle(.menu)
                if let metric = metrics.first(where: { $0.id == selection.wrappedValue }) {
                    ComparisonMetricChart(metric: metric, period: period, referenceDate: referenceDate)
                        .id(metric.id)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

private struct ComparisonMetricChart: View {
    let metric: HealthMetric
    let period: TimePeriod
    let referenceDate: Date
    @State private var viewModel = MetricDetailViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var chartHeight: CGFloat = 220
    @State private var availableWidth: CGFloat = 0

    private var axisCount: Int {
        dynamicTypeSize.isAccessibilitySize || availableWidth < 360 ? 2 : 4
    }

    private var range: ClosedRange<Date> {
        let dates = period.dateRange(referenceDate: referenceDate)
        return dates.start...dates.end
    }

    private var weeklyAxisDates: [Date] {
        // Keep sparse weekly ticks inside the domain instead of relying on automatic date strides.
        let dayOffsets = axisCount == 2 ? [1, 4] : [0, 2, 4, 6]
        return dayOffsets.compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: range.lowerBound)
        }
    }

    private var chartUnit: String {
        metric.category == .sleep ? String(localized: "Minutes") : (viewModel.metricUnit.isEmpty ? metric.unit : viewModel.metricUnit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(metric.name).font(.headline)
            Text(range.lowerBound.formatted(date: .abbreviated, time: .omitted) + " – " + range.upperBound.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("comparison-date-range")
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 220)
            } else if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(.secondary)
                Button("Retry") { Task { await viewModel.loadData() } }
            } else {
                let points = viewModel.chartData.filter {
                    range.contains($0.date) && $0.value.isFinite && (metric.category != .sleep || $0.value > 0)
                }
                if points.isEmpty {
                    ContentUnavailableView("No Data", systemImage: "chart.xyaxis.line")
                } else {
                    Chart(points) { point in
                        if metric.category == .sleep {
                            BarMark(x: .value("Date", point.date), y: .value(chartUnit, point.value))
                                .foregroundStyle(metric.category.themeColor)
                                .accessibilityValue("\(point.value.formatted()) \(chartUnit)")
                        } else {
                            LineMark(x: .value("Date", point.date), y: .value(chartUnit, point.value))
                                .foregroundStyle(metric.category.themeColor)
                            PointMark(x: .value("Date", point.date), y: .value(chartUnit, point.value))
                                .foregroundStyle(metric.category.themeColor)
                                .accessibilityValue("\(point.value.formatted()) \(chartUnit)")
                        }
                    }
                    .chartXScale(domain: range)
                    .chartXAxis {
                        if period == .week {
                            AxisMarks(values: weeklyAxisDates) {
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            }
                        } else {
                            AxisMarks(values: .automatic(desiredCount: axisCount)) {
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel()
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: axisCount)) {
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                    .chartYAxisLabel(chartUnit)
                    .frame(height: max(220, chartHeight))
                    .accessibilityLabel(Text(metric.name))
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
        .task(id: period) {
            viewModel.configure(category: metric.category, currentValue: metric.value,
                                lastUpdated: metric.date, workoutTypeName: metric.workoutTypeKey,
                                metricUnit: metric.unit)
            if viewModel.selectedPeriod != period {
                // Changing the period already schedules a reload in the shared model.
                viewModel.selectedPeriod = period
            } else {
                await viewModel.loadData()
            }
        }
    }
}
