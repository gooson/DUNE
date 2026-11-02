import SwiftUI

/// Unified detail view for all metric types.
/// Shows summary header, period picker, chart (scrollable), highlights, and "Show All Data" link.
struct MetricDetailView: View {
    let metric: HealthMetric

    @State private var viewModel = MetricDetailViewModel()
    @State private var showShimmer = false
    @State private var shimmerTask: Task<Void, Never>?
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                MetricQuantityHero(
                    metric: resolvedMetric,
                    unitOverride: resolvedMetric.unit
                )
                .staggeredAppear(index: 0)

                StandardCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        chartHeader
                        Picker("Period", selection: $viewModel.selectedPeriod) {
                            ForEach(TimePeriod.allCases, id: \.self) { period in
                                Text(period.displayName).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)

                        if let limitedStart = viewModel.limitedHistoryStartDate,
                           viewModel.scrollPosition < limitedStart {
                            LimitedHealthHistoryNotice()
                        }

                        historyNavigation

                        // Recreate chart selection only when the period changes.
                        Group {
                            if viewModel.chartData.isEmpty && viewModel.earliestHistoryDate == nil && !viewModel.isLoading {
                                chartEmptyState
                            } else {
                                chart
                                    .overlay {
                                        ChartUITestSurface(
                                            identifier: "detail-chart-surface",
                                            label: "\(metric.category.englishDisplayName) Detail Chart",
                                            value: viewModel.visibleRangeLabel
                                        )
                                    }
                            }
                        }
                        .id(viewModel.selectedPeriod)
                        .transition(.opacity)

                        MetricHistorySummary(
                            category: metric.category,
                            summary: viewModel.visibleSummary,
                            unitOverride: viewModel.metricUnit.isEmpty ? metric.unit : viewModel.metricUnit
                        )
                    }
                }
                .overlay {
                    if showShimmer {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(theme.accentColor.opacity(0.25))
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)
                .onChange(of: viewModel.selectedPeriod) {
                    shimmerTask?.cancel()
                    guard !reduceMotion else {
                        showShimmer = false
                        shimmerTask = nil
                        return
                    }

                    showShimmer = true
                    shimmerTask = Task {
                        try? await Task.sleep(for: .milliseconds(120))
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            withAnimation(DS.Animation.shimmer) {
                                showShimmer = false
                            }
                        }
                    }
                }
                .onDisappear {
                    shimmerTask?.cancel()
                    shimmerTask = nil
                }
                .staggeredAppear(index: 3)

                if [.weight, .bmi, .bodyFat, .leanBodyMass].contains(metric.category) {
                    BodyPeerComparisonCard(metric: resolvedMetric)
                        .staggeredAppear(index: 4)
                }

                // Sleep sections grouped by category
                if metric.category == .sleep {
                    // Group 1: Sleep Quality
                    SectionGroup(
                        title: "Sleep Quality",
                        icon: "bed.double.fill",
                        iconColor: DS.Color.sleep,
                        subtitle: "Analyzes sleep debt, recovery forecast, and awakening patterns",
                        sectionIdentifier: "sleep-section-quality"
                    ) {
                        if let deficit = viewModel.deficitAnalysis,
                           deficit.level != .insufficient {
                            SleepDeficitGaugeView(analysis: deficit)
                        }
                        WakeAnalysisCard(analysis: viewModel.wasoAnalysis)
                        SleepDebtRecoveryCard(prediction: viewModel.debtRecoveryPrediction)
                    }
                    .staggeredAppear(index: 4)

                    // Group 2: Sleep Patterns
                    SectionGroup(
                        title: "Sleep Patterns",
                        icon: "clock.badge.checkmark",
                        iconColor: DS.Color.sleep,
                        subtitle: "Tracks bedtime regularity and nap patterns",
                        sectionIdentifier: "sleep-section-patterns"
                    ) {
                        if let averageBedtime = viewModel.averageBedtime {
                            AverageBedtimeCard(averageBedtime: averageBedtime)
                        }
                        SleepRegularityCard(regularity: viewModel.sleepRegularity)
                        NapDetectionCard(analysis: viewModel.napAnalysis)
                    }
                    .staggeredAppear(index: 5)

                    // Group 3: Nocturnal Health
                    SectionGroup(
                        title: "Nocturnal Health",
                        icon: "heart.text.clipboard",
                        iconColor: DS.Color.sleep,
                        subtitle: "Monitors heart rate, breathing, and oxygen levels during sleep",
                        sectionIdentifier: "sleep-section-nocturnal"
                    ) {
                        NocturnalVitalsChartView(snapshot: viewModel.nocturnalVitals)
                        VitalsTimelineCard(analysis: viewModel.vitalsTimeline)
                        BreathingDisturbanceCard(analysis: viewModel.breathingAnalysis)
                    }
                    .staggeredAppear(index: 6)

                    // Group 4: External Factors
                    SectionGroup(
                        title: "External Factors",
                        icon: "arrow.triangle.branch",
                        iconColor: DS.Color.sleep,
                        subtitle: "Explores how exercise and environment affect your sleep",
                        sectionIdentifier: "sleep-section-external"
                    ) {
                        SleepExerciseCorrelationCard(correlation: viewModel.exerciseCorrelation)
                        SleepEnvironmentCard(analysis: viewModel.sleepEnvironment)
                    }
                    .staggeredAppear(index: 7)
                }

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
                                category: metric.category,
                                resolvedChartUnit: viewModel.metricUnit
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .staggeredAppear(index: 4)
                } else {
                    if metric.category == .exercise, let totals = viewModel.exerciseTotals {
                        ExerciseTotalsView(totals: totals, tintColor: metric.category.themeColor)
                            .staggeredAppear(index: 4)
                    }
                    MetricHighlightsView(
                        highlights: viewModel.highlights,
                        category: metric.category,
                        resolvedChartUnit: viewModel.metricUnit
                    )
                    .staggeredAppear(index: 5)
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
                .accessibilityIdentifier("metric-detail-show-all-data")
                .staggeredAppear(index: 6)
            }
            .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("metric-detail-screen-\(metric.category.rawValue)")
        .background { DetailWaveBackground() }
        .environment(\.waveColor, metric.category.themeColor)
        .englishNavigationTitle(metric.workoutTypeKey ?? metric.category.englishDisplayName)
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
                workoutTypeName: metric.workoutTypeKey,
                metricUnit: metric.unit
            )
            await viewModel.loadData()
        }
    }

    private var resolvedMetric: HealthMetric {
        MetricDetailHeadline.resolve(
            metric,
            stepsValue: viewModel.hasConfiguredValue ? viewModel.currentValue : nil,
            stepsUpdated: viewModel.lastUpdated
        )
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
                .foregroundStyle(DS.Color.textSecondary)

            Text("No records for this period.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 220)
    }

    // MARK: - Chart Header

    private var chartHeader: some View {
        HStack {
            Text("History")
                .font(DS.Typography.sectionTitle)

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
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: viewModel.showTrendLine)
        }
    }

    private var historyNavigation: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                viewModel.stepVisiblePeriod(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canStepBackward)
            .accessibilityLabel("Previous period")
            .accessibilityIdentifier("detail-chart-previous-period")

            Text(viewModel.visibleRangeLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("detail-chart-visible-range")

            Button {
                viewModel.stepVisiblePeriod(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 44, height: 44)
            }
            .disabled(!viewModel.canStepForward)
            .accessibilityLabel("Next period")
            .accessibilityIdentifier("detail-chart-next-period")
        }
        .buttonStyle(.plain)
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
                scrollDomain: viewModel.scrollDomain,
                scrollPosition: $viewModel.scrollPosition
            )

        case .rhr:
            if !viewModel.rangeData.isEmpty {
                RangeBarChartView(
                    data: viewModel.rangeData,
                    period: viewModel.selectedPeriod,
                    tintColor: DS.Color.rhr,
                    trendLine: trend,
                    scrollDomain: viewModel.scrollDomain,
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
                    scrollDomain: viewModel.scrollDomain,
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
                scrollDomain: viewModel.scrollDomain,
                scrollPosition: $viewModel.scrollPosition
            )

        case .steps:
            BarChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.steps,
                valueLabel: "Steps",
                trendLine: trend,
                scrollDomain: viewModel.scrollDomain,
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
                scrollDomain: viewModel.scrollDomain,
                scrollPosition: $viewModel.scrollPosition
            )

        case .weight:
            AreaLineChartView(
                data: viewModel.visibleWeightChartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.body,
                unitSuffix: "kg",
                trendLine: trend,
                scrollDomain: viewModel.scrollDomain,
                fixedYDomain: viewModel.weightYDomain,
                scrollPosition: $viewModel.scrollPosition
            )

        case .bmi:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.body,
                unitSuffix: "",
                trendLine: trend,
                scrollDomain: viewModel.scrollDomain,
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
                scrollDomain: viewModel.scrollDomain,
                scrollPosition: $viewModel.scrollPosition
            )

        case .respiratoryRate:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.vitals,
                unitSuffix: " breaths/min",
                trendLine: trend,
                scrollDomain: viewModel.scrollDomain,
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
                scrollDomain: viewModel.scrollDomain,
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
                scrollDomain: viewModel.scrollDomain,
                scrollPosition: $viewModel.scrollPosition
            )

        case .heartRate:
            if !viewModel.rangeData.isEmpty {
                RangeBarChartView(
                    data: viewModel.rangeData,
                    period: viewModel.selectedPeriod,
                    tintColor: DS.Color.heartRate,
                    trendLine: trend,
                    scrollDomain: viewModel.scrollDomain,
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
                    scrollDomain: viewModel.scrollDomain,
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
                scrollDomain: viewModel.scrollDomain,
                scrollPosition: $viewModel.scrollPosition
            )

        case .leanBodyMass:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.body,
                unitSuffix: "kg",
                trendLine: trend,
                scrollDomain: viewModel.scrollDomain,
                scrollPosition: $viewModel.scrollPosition
            )

        case .wristTemperature:
            AreaLineChartView(
                data: viewModel.chartData,
                period: viewModel.selectedPeriod,
                tintColor: DS.Color.vitals,
                unitSuffix: "°C",
                trendLine: trend,
                scrollDomain: viewModel.scrollDomain,
                scrollPosition: $viewModel.scrollPosition
            )

        case .breathingDisturbances:
            DotLineChartView(
                data: viewModel.chartData,
                baseline: nil,
                yAxisLabel: "/hr",
                timePeriod: viewModel.selectedPeriod,
                tintColor: DS.Color.sleep,
                trendLine: trend,
                scrollDomain: viewModel.scrollDomain,
                scrollPosition: $viewModel.scrollPosition
            )
        }
    }

}

// MARK: - Navigation Destination

struct AllDataDestination: Hashable {
    let category: HealthMetric.Category
}
