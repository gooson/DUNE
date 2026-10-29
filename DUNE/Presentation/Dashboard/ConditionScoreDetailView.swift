import SwiftUI

/// Condition evidence and one synchronized history card, with a single explanation disclosure.
struct ConditionScoreDetailView: View {
    let score: ConditionScore
    let scoreRefreshService: ScoreRefreshService?

    @State private var viewModel: ConditionScoreDetailViewModel
    @State private var isExplainerExpanded = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme

    init(score: ConditionScore, scoreRefreshService: ScoreRefreshService? = nil) {
        self.score = score
        self.scoreRefreshService = scoreRefreshService
        _viewModel = State(initialValue: ConditionScoreDetailViewModel(scoreRefreshService: scoreRefreshService))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                ConditionDetailHeader(score: score)
                ConditionInsightSection(status: score.status)

                if let detail = score.detail {
                    TimeOfDayCard(
                        currentAdjustment: detail.timeOfDayAdjustment,
                        baseScore: detail.rawScore - detail.timeOfDayAdjustment,
                        usesAdaptiveLayout: true
                    )
                    .accessibilityIdentifier("condition-time-of-day")
                }

                trendCard

                if !viewModel.highlights.isEmpty {
                    ScoreDetailHighlights(highlights: viewModel.highlights)
                }
                if viewModel.selectedPeriod != .day {
                    SubScoreTrendChartView(
                        title: "HRV", data: viewModel.hrvTrend,
                        color: DS.Color.hrv, unit: "ms", fractionDigits: 1
                    )
                    .accessibilityIdentifier("condition-subscore-hrv")
                    SubScoreTrendChartView(
                        title: "Resting Heart Rate", data: viewModel.rhrTrend,
                        color: DS.Color.heartRate, unit: "bpm"
                    )
                    .accessibilityIdentifier("condition-subscore-rhr")
                }

                ConditionScoreBreakdownView(detail: score.detail)
                explanation
            }
            .frame(maxWidth: DS.Layout.rootContentMaxWidth)
            .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("condition-score-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Condition Score")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading && viewModel.chartData.isEmpty { ProgressView() }
        }
        .task {
            viewModel.configure(score: score)
            await viewModel.loadData()
        }
    }

    private var trendCard: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        trendTitle
                        Spacer()
                        trendToggle
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        trendTitle
                        trendToggle
                    }
                }
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("condition-period-picker")
                .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)

                HStack(spacing: DS.Spacing.xs) {
                    Button {
                        viewModel.stepVisiblePeriod(by: -1)
                    } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Previous period")
                    .accessibilityIdentifier("condition-period-previous")
                    .disabled(!viewModel.canStepBackward)

                    Text(viewModel.visibleRangeLabel)
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("score-detail-chart-visible-range")

                    Button {
                        viewModel.stepVisiblePeriod(by: 1)
                    } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Next period")
                    .accessibilityIdentifier("condition-period-next")
                    .disabled(!viewModel.canStepForward)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.sandColor)

                if let limitedStart = viewModel.limitedHistoryStartDate,
                   viewModel.scrollPosition < limitedStart {
                    LimitedHealthHistoryNotice()
                }

                chart
                if let summary = viewModel.visibleSummaryStats {
                    Divider()
                    visibleSummary(summary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("condition-trend-card")
    }

    private var trendTitle: some View {
        Label("Condition Trend", systemImage: "chart.xyaxis.line")
            .font(.subheadline.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var trendToggle: some View {
        Button {
            withAnimation(reduceMotion ? nil : DS.Animation.snappy) {
                viewModel.showTrendLine.toggle()
            }
        } label: {
            Label("Trend", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption.weight(.medium))
                .padding(.horizontal, DS.Spacing.sm)
                .frame(minHeight: 44)
                .background(viewModel.showTrendLine ? theme.accentColor.opacity(0.12) : Color.clear,
                            in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(viewModel.showTrendLine ? theme.accentColor : .secondary)
        .accessibilityIdentifier("score-chart-trend-toggle")
        .accessibilityValue(viewModel.showTrendLine ? Text("On") : Text("Off"))
        .sensoryFeedback(.selection, trigger: viewModel.showTrendLine)
    }

    private var chart: some View {
        Group {
            if viewModel.chartData.isEmpty && !viewModel.isLoading {
                ScoreDetailEmptyState(chartHeight: chartHeight)
            } else {
                DotLineChartView(
                    data: viewModel.chartData, baseline: 50, yAxisLabel: "Score",
                    timePeriod: viewModel.selectedPeriod, tintColor: score.status.color,
                    trendLine: viewModel.trendLineData, scrollDomain: viewModel.scrollDomain,
                    scrollPosition: $viewModel.scrollPosition
                )
                .frame(height: chartHeight)
                .overlay {
                    ChartUITestSurface(identifier: "detail-chart-surface", label: "Condition Detail Chart",
                                       value: viewModel.visibleRangeLabel)
                }
                .chartSelectionUITestProbe("visible-points:\(viewModel.visibleChartPointCount)",
                                           identifier: "condition-history-probe")
            }
        }
        .id(viewModel.selectedPeriod)
    }

    private func visibleSummary(_ summary: MetricSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Period Summary").font(.caption).foregroundStyle(DS.Color.textSecondary)
            if dynamicTypeSize.isAccessibilitySize {
                summaryItems(summary)
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.md) { summaryItems(summary) }
            }
            if summary.changePercentage != nil {
                ChangeBadge(change: summary.changePercentage)
                    .accessibilityIdentifier("condition-summary-change")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("condition-visible-summary")
    }

    @ViewBuilder
    private func summaryItems(_ summary: MetricSummary) -> some View {
        summaryItem("Avg", value: summary.average, identifier: "average")
        summaryItem("Min", value: summary.min, identifier: "min")
        summaryItem("Max", value: summary.max, identifier: "max")
    }

    private func summaryItem(_ label: LocalizedStringKey, value: Double, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(label).font(.caption2).foregroundStyle(DS.Color.textSecondary)
            Text(value.formattedWithSeparator())
                .font(.title3.bold().monospacedDigit())
                .accessibilityIdentifier("condition-summary-\(identifier)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var explanation: some View {
        StandardCard {
            DisclosureGroup(isExpanded: $isExplainerExpanded) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if let detail = score.detail {
                        ConditionCalculationCard(detail: detail, isEmbedded: true)
                    }
                    ConditionExplainerSection()
                }
                .padding(.top, DS.Spacing.md)
            } label: {
                Label("How the Score Works", systemImage: "info.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44, alignment: .leading)
            }
            .tint(theme.sandColor)
            .accessibilityIdentifier("condition-score-explainer")
        }
    }

    private var chartHeight: CGFloat { sizeClass == .regular ? 360 : 250 }
}
