import SwiftUI

/// Unified detail view for all metric types.
/// Shows summary header, period picker, chart (category-specific), highlights, and "Show All Data" link.
struct MetricDetailView: View {
    let metric: HealthMetric

    @State private var viewModel = MetricDetailViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // Summary header
                MetricSummaryHeader(
                    category: metric.category,
                    currentValue: metric.value,
                    summary: viewModel.summaryStats,
                    lastUpdated: viewModel.lastUpdated
                )

                // Period picker + range label
                VStack(spacing: DS.Spacing.xs) {
                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)

                    periodRangeLabel
                }

                // Chart (swipeable)
                StandardCard {
                    chart
                        .frame(height: chartHeight)
                }
                .periodSwipe(offset: $viewModel.periodOffset, canGoForward: viewModel.canGoForward)

                // Highlights
                MetricHighlightsView(
                    highlights: viewModel.highlights,
                    category: metric.category
                )

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
            .padding()
        }
        .navigationTitle(metric.category.displayName)
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
                lastUpdated: metric.date
            )
            await viewModel.loadData()
        }
    }

    // MARK: - Period Range Label

    @ViewBuilder
    private var periodRangeLabel: some View {
        let label = viewModel.selectedPeriod.rangeLabel(offset: viewModel.periodOffset)
        if !label.isEmpty {
            HStack {
                Button {
                    viewModel.periodOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }

                Spacer()

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())

                Spacer()

                if viewModel.canGoForward {
                    Button {
                        viewModel.periodOffset += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .sensoryFeedback(.selection, trigger: viewModel.periodOffset)
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chart: some View {
        switch metric.category {
        case .hrv:
            DotLineChartView(
                data: viewModel.chartData,
                baseline: nil,
                yAxisLabel: "ms",
                timePeriod: viewModel.selectedPeriod,
                tintColor: DS.Color.hrv
            )

        case .rhr:
            if !viewModel.rangeData.isEmpty {
                RangeBarChartView(
                    data: viewModel.rangeData,
                    period: viewModel.selectedPeriod,
                    tintColor: DS.Color.rhr
                )
            } else {
                DotLineChartView(
                    data: viewModel.chartData,
                    baseline: nil,
                    yAxisLabel: "bpm",
                    timePeriod: viewModel.selectedPeriod,
                    tintColor: DS.Color.rhr
                )
            }

        case .sleep:
            BarChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.sleep,
                valueLabel: "Sleep",
                unitSuffix: " min"
            )

        case .steps:
            BarChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.steps,
                valueLabel: "Steps"
            )

        case .exercise:
            BarChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.activity,
                valueLabel: "Exercise",
                unitSuffix: " min"
            )

        case .weight:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.body,
                unitSuffix: "kg"
            )
        }
    }

    private var chartHeight: CGFloat {
        sizeClass == .regular ? 300 : 250
    }
}

// MARK: - Navigation Destination

struct AllDataDestination: Hashable {
    let category: HealthMetric.Category
}
