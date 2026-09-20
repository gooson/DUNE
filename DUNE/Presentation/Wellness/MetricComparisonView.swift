import Charts
import SwiftUI

/// Uses one period and date domain, while keeping each metric's units and scale independent.
struct MetricComparisonView: View {
    let metrics: [HealthMetric]
    @Environment(\.dismiss) private var dismiss
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
            VStack(spacing: DS.Spacing.md) {
                Picker("Period", selection: $period) {
                    ForEach(TimePeriod.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("metric-comparison-period")

                Text("Same dates; separate scales. Trends do not establish cause.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                AdaptivePaneView {
                    pane(selection: $firstID, title: "First Metric", identifier: "metric-comparison-first")
                } secondary: {
                    pane(selection: $secondID, title: "Second Metric", identifier: "metric-comparison-second")
                }
            }
            .padding(DS.Spacing.md)
            .navigationTitle("Compare Metrics")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func pane(selection: Binding<String>, title: LocalizedStringKey, identifier: String) -> some View {
        ScrollView {
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
            .padding(DS.Spacing.md)
        }
        .accessibilityIdentifier(identifier)
    }
}

private struct ComparisonMetricChart: View {
    let metric: HealthMetric
    let period: TimePeriod
    let referenceDate: Date
    @State private var viewModel = MetricDetailViewModel()

    private var range: ClosedRange<Date> {
        let dates = period.dateRange(referenceDate: referenceDate)
        return dates.start...dates.end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(metric.name).font(.headline)
            Text(range.lowerBound.formatted(date: .abbreviated, time: .omitted) + " – " + range.upperBound.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 220)
            } else if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(.secondary)
                Button("Retry") { Task { await viewModel.loadData() } }
            } else {
                let points = viewModel.chartData.filter { range.contains($0.date) && $0.value.isFinite }
                if points.isEmpty {
                    ContentUnavailableView("No Data", systemImage: "chart.xyaxis.line")
                } else {
                    Chart(points) { point in
                        LineMark(x: .value("Date", point.date), y: .value(metric.unit, point.value))
                            .foregroundStyle(metric.category.themeColor)
                        PointMark(x: .value("Date", point.date), y: .value(metric.unit, point.value))
                            .foregroundStyle(metric.category.themeColor)
                    }
                    .chartXScale(domain: range)
                    .chartYAxisLabel(viewModel.metricUnit.isEmpty ? metric.unit : viewModel.metricUnit)
                    .frame(height: 220)
                    .clipped()
                    .accessibilityLabel(Text(metric.name))
                }
            }
        }
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
