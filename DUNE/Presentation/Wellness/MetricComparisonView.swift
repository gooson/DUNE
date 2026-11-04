import Charts
import SwiftUI

/// Uses one period and date domain, while keeping each metric's units and scale independent.
struct MetricComparisonView: View {
    let metrics: [HealthMetric]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var availableWidth: CGFloat = 0
    @State private var firstID: String
    @State private var secondID: String
    @State private var period: TimePeriod = .week
    @State private var referenceDate = Date()

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }
    private var sharedRange: ClosedRange<Date> {
        let dates = period.dateRange(referenceDate: referenceDate)
        return dates.start...dates.end
    }
    private func rangeText(_ range: ClosedRange<Date>) -> String {
        range.lowerBound.formatted(date: .abbreviated, time: .omitted) + " – " +
            range.upperBound.formatted(date: .abbreviated, time: .omitted)
    }

    init(metrics: [HealthMetric]) {
        self.metrics = metrics
        _firstID = State(initialValue: metrics.first?.id ?? "")
        _secondID = State(initialValue: metrics.dropFirst().first?.id ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let domain = sharedRange
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    comparisonHero
                    periodControl
                    Text(rangeText(domain))
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("comparison-date-range")

                    Text("Same dates; separate scales. Trends do not establish cause.")
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    let layout = availableWidth >= 760 && !dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.md))
                        : AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
                    layout {
                        pane(selection: $firstID, title: "First Metric", identifier: "metric-comparison-first", range: domain)
                        pane(selection: $secondID, title: "Second Metric", identifier: "metric-comparison-second", range: domain)
                    }
                }
                .padding(DS.Spacing.md)
            }
            .accessibilityIdentifier("metric-comparison-scroll")
            .background { SheetWaveBackground().opacity(0.42) }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("metric-comparison-done")
                }
            }
        }
        .presentationDetents([.large])
    }

    private var comparisonHero: some View {
        Label("Compare Metrics", systemImage: "chart.xyaxis.line")
            .font(.title3.weight(.bold))
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.lg)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(palette.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("metric-comparison-title")
    }

    @ViewBuilder
    private var periodControl: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Period").font(.headline)
                ForEach(TimePeriod.allCases, id: \.self) { option in
                    Button {
                        period = option
                    } label: {
                        HStack {
                            Text(option.displayName).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: DS.Spacing.sm)
                            if period == option {
                                Image(systemName: "checkmark")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DS.Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(period == option ? Color.primary : DS.Color.textSecondary)
                    .accessibilityAddTraits(period == option ? .isSelected : [])
                    .accessibilityIdentifier("metric-comparison-period-\(option.rawValue)")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("metric-comparison-period-options")
        } else {
            Picker("Period", selection: $period) {
                ForEach(TimePeriod.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                        .accessibilityIdentifier("metric-comparison-period-\($0.rawValue)")
                }
            }
            .pickerStyle(.menu)
            .tint(DS.Color.textSecondary)
            .accessibilityIdentifier("metric-comparison-period")
        }
    }

    private func pane(selection: Binding<String>, title: LocalizedStringKey, identifier: String, range: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if dynamicTypeSize.isAccessibilitySize {
                    Menu {
                        ForEach(metrics) { metric in
                            Button {
                                selection.wrappedValue = metric.id
                            } label: {
                                if selection.wrappedValue == metric.id {
                                    Label(metric.name, systemImage: "checkmark")
                                } else {
                                    Text(metric.name)
                                }
                            }
                            .accessibilityAddTraits(selection.wrappedValue == metric.id ? .isSelected : [])
                            .accessibilityIdentifier("\(identifier)-option-\(metric.category.rawValue)")
                        }
                    } label: {
                        HStack(alignment: .top, spacing: DS.Spacing.sm) {
                            if let metric = metrics.first(where: { $0.id == selection.wrappedValue }) {
                                Image(systemName: metric.resolvedIconName)
                                    .foregroundStyle(metric.category.themeColor)
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                Text(title)
                                    .foregroundStyle(.primary)
                                if let metric = metrics.first(where: { $0.id == selection.wrappedValue }) {
                                    Text(metric.name)
                                        .foregroundStyle(DS.Color.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: DS.Spacing.sm)
                            Image(systemName: "chevron.up.chevron.down")
                                .foregroundStyle(DS.Color.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("\(identifier)-picker")
                } else {
                    HStack(alignment: .center, spacing: DS.Spacing.sm) {
                        if let metric = metrics.first(where: { $0.id == selection.wrappedValue }) {
                            Image(systemName: metric.resolvedIconName)
                                .foregroundStyle(metric.category.themeColor)
                                .accessibilityHidden(true)
                        }
                        Picker(title, selection: selection) {
                            ForEach(metrics) { metric in
                                Text(metric.name)
                                    .tag(metric.id)
                                    .accessibilityIdentifier("\(identifier)-option-\(metric.category.rawValue)")
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(DS.Color.textSecondary)
                        .accessibilityIdentifier("\(identifier)-picker")
                    }
                }
                if let metric = metrics.first(where: { $0.id == selection.wrappedValue }) {
                    ComparisonMetricChart(metric: metric, period: period, range: range, identifier: identifier)
                        .id(metric.id)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(DS.Color.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}

private struct ComparisonMetricChart: View {
    let metric: HealthMetric
    let period: TimePeriod
    let range: ClosedRange<Date>
    let identifier: String
    @State private var viewModel = MetricDetailViewModel()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption) private var chartHeight: CGFloat = 220
    @State private var availableWidth: CGFloat = 0

    private var axisCount: Int {
        dynamicTypeSize.isAccessibilitySize || availableWidth < 360 ? 2 : 4
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
        let plotColor = colorScheme == .light
            ? metric.category.themeColor.mix(with: .black, by: 0.35)
            : metric.category.themeColor
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(metric.name).font(.headline)
            if let limitedStart = viewModel.limitedHistoryStartDate,
               range.lowerBound < limitedStart {
                LimitedHealthHistoryNotice()
            }
            if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 220)
            } else if let message = viewModel.errorMessage {
                Text(message).foregroundStyle(DS.Color.textSecondary)
                Button("Retry") { Task { await viewModel.loadData() } }
            } else {
                let points = viewModel.chartData.filter {
                    range.contains($0.date) && $0.value.isFinite && (metric.category != .sleep || $0.value > 0)
                }
                if points.isEmpty {
                    ContentUnavailableView("No Data", systemImage: "chart.xyaxis.line")
                } else {
                    Text(chartUnit)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Chart(points) { point in
                        if metric.category == .sleep {
                            BarMark(x: .value("Date", point.date), y: .value(chartUnit, point.value))
                                .foregroundStyle(plotColor)
                                .accessibilityValue("\(point.value.formatted()) \(chartUnit)")
                        } else {
                            LineMark(x: .value("Date", point.date), y: .value(chartUnit, point.value))
                                .foregroundStyle(plotColor)
                            PointMark(x: .value("Date", point.date), y: .value(chartUnit, point.value))
                                .foregroundStyle(plotColor)
                                .accessibilityValue("\(point.value.formatted()) \(chartUnit)")
                        }
                    }
                    .accessibilityIdentifier("\(identifier)-plot")
                    .chartXScale(domain: range)
                    .chartXAxis {
                        if period == .week {
                            AxisMarks(values: weeklyAxisDates) {
                                AxisGridLine()
                                AxisTick()
                                if dynamicTypeSize.isAccessibilitySize {
                                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                                        .foregroundStyle(DS.Color.textSecondary)
                                } else {
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                        .foregroundStyle(DS.Color.textSecondary)
                                }
                            }
                        } else {
                            AxisMarks(values: .automatic(desiredCount: axisCount)) {
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel()
                                    .foregroundStyle(DS.Color.textSecondary)
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: axisCount)) {
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel()
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
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
