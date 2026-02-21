import SwiftUI

/// Unified detail view for all metric types.
/// Shows summary header, period picker, chart (scrollable), highlights, and "Show All Data" link.
struct MetricDetailView: View {
    let metric: HealthMetric

    @State private var viewModel = MetricDetailViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // Summary header
                MetricSummaryHeader(
                    category: metric.category,
                    currentValue: metric.value,
                    summary: viewModel.summaryStats,
                    lastUpdated: viewModel.lastUpdated,
                    unitOverride: viewModel.metricUnit.isEmpty ? nil : viewModel.metricUnit
                )

                // Period picker
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)

                // Chart header: visible range + trend toggle
                chartHeader

                // Chart (natively scrollable)
                // Note: .id() forces full view recreation on period change,
                // intentionally resetting chart @State (e.g. selectedDate) for clean transition.
                StandardCard {
                    Group {
                        if viewModel.chartData.isEmpty && !viewModel.isLoading {
                            chartEmptyState
                        } else {
                            chart
                                .frame(height: chartHeight)
                        }
                    }
                    .id(viewModel.selectedPeriod)
                    .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)

                // Exercise totals + Highlights
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: DS.Spacing.lg) {
                        if metric.category == .exercise, let totals = viewModel.exerciseTotals {
                            ExerciseTotalsView(totals: totals, tintColor: metric.category.themeColor)
                                .frame(maxWidth: .infinity)
                        }
                        if !viewModel.highlights.isEmpty {
                            MetricHighlightsView(
                                highlights: viewModel.highlights,
                                category: metric.category
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    if metric.category == .exercise, let totals = viewModel.exerciseTotals {
                        ExerciseTotalsView(totals: totals, tintColor: metric.category.themeColor)
                    }
                    MetricHighlightsView(
                        highlights: viewModel.highlights,
                        category: metric.category
                    )
                }

                // Show All Data
                NavigationLink(value: AllDataDestination(category: metric.category)) {
                    HStack {
                        Text("Show All Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(DS.Spacing.lg)
                    .background {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(.thinMaterial)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
        .navigationTitle(metric.name)
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading && viewModel.chartData.isEmpty {
                ProgressView()
            }
        }
        .task {
            viewModel.configure(
                category: metric.category,
                currentValue: metric.value,
                lastUpdated: metric.date,
                workoutTypeName: metric.iconOverride != nil ? metric.name : nil,
                metricUnit: metric.unit
            )
            await viewModel.loadData()
        }
    }

    // MARK: - Empty State

    private var chartEmptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)

            Text("No Data")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text("No records for this period.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: chartHeight)
    }

    // MARK: - Chart Header

    private var chartHeader: some View {
        HStack {
            Text(viewModel.visibleRangeLabel)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(DS.Animation.snappy, value: viewModel.visibleRangeLabel)

            Spacer()

            Button {
                withAnimation(DS.Animation.snappy) {
                    viewModel.showTrendLine.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                    Text("Trend")
                        .font(.caption)
                }
                .foregroundStyle(viewModel.showTrendLine ? metric.category.themeColor : .secondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule()
                        .fill(viewModel.showTrendLine
                              ? metric.category.themeColor.opacity(0.12)
                              : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: viewModel.showTrendLine)
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chart: some View {
        let trend = viewModel.trendLineData

        switch metric.category {
        case .hrv:
            DotLineChartView(
                data: viewModel.chartData,
                baseline: nil,
                yAxisLabel: "ms",
                timePeriod: viewModel.selectedPeriod,
                tintColor: DS.Color.hrv,
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .rhr:
            if !viewModel.rangeData.isEmpty {
                RangeBarChartView(
                    data: viewModel.rangeData,
                    period: viewModel.selectedPeriod,
                    tintColor: DS.Color.rhr,
                    trendLine: trend,
                    scrollPosition: $viewModel.scrollPosition
                )
            } else {
                DotLineChartView(
                    data: viewModel.chartData,
                    baseline: nil,
                    yAxisLabel: "bpm",
                    timePeriod: viewModel.selectedPeriod,
                    tintColor: DS.Color.rhr,
                    trendLine: trend,
                    scrollPosition: $viewModel.scrollPosition
                )
            }

        case .sleep:
            BarChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.sleep,
                valueLabel: "Sleep",
                unitSuffix: " min",
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .steps:
            BarChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.steps,
                valueLabel: "Steps",
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .exercise:
            BarChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.activity,
                valueLabel: "Exercise",
                unitSuffix: viewModel.metricUnit == "km" ? " km" : " min",
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .weight:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.body,
                unitSuffix: "kg",
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .bmi:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.body,
                unitSuffix: "",
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .spo2:
            DotLineChartView(
                data: viewModel.chartData,
                baseline: nil,
                yAxisLabel: "%",
                timePeriod: viewModel.selectedPeriod,
                tintColor: DS.Color.vitals,
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .respiratoryRate:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.vitals,
                unitSuffix: " breaths/min",
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .vo2Max:
            DotLineChartView(
                data: viewModel.chartData,
                baseline: nil,
                yAxisLabel: "ml/kg/min",
                timePeriod: viewModel.selectedPeriod,
                tintColor: DS.Color.fitness,
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .heartRateRecovery:
            DotLineChartView(
                data: viewModel.chartData,
                baseline: nil,
                yAxisLabel: "bpm",
                timePeriod: viewModel.selectedPeriod,
                tintColor: DS.Color.fitness,
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .heartRate:
            if !viewModel.rangeData.isEmpty {
                RangeBarChartView(
                    data: viewModel.rangeData,
                    period: viewModel.selectedPeriod,
                    tintColor: DS.Color.heartRate,
                    trendLine: trend,
                    scrollPosition: $viewModel.scrollPosition
                )
            } else {
                DotLineChartView(
                    data: viewModel.chartData,
                    baseline: nil,
                    yAxisLabel: "bpm",
                    timePeriod: viewModel.selectedPeriod,
                    tintColor: DS.Color.heartRate,
                    trendLine: trend,
                    scrollPosition: $viewModel.scrollPosition
                )
            }

        case .bodyFat:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.body,
                unitSuffix: "%",
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .leanBodyMass:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.body,
                unitSuffix: "kg",
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )

        case .wristTemperature:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.vitals,
                unitSuffix: "°C",
                trendLine: trend,
                scrollPosition: $viewModel.scrollPosition
            )
        }
    }

    private var chartHeight: CGFloat {
        sizeClass == .regular ? 360 : 250
    }
}

// MARK: - Navigation Destination

struct AllDataDestination: Hashable {
    let category: HealthMetric.Category
}
