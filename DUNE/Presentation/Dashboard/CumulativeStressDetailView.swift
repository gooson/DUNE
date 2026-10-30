import SwiftUI

/// Detail view for the Cumulative Stress Score.
/// Keeps original evidence and guidance around a unified history card and calculation disclosure.
struct CumulativeStressDetailView: View {
    let stressScore: CumulativeStressScore
    let scoreRefreshService: ScoreRefreshService?

    @State private var viewModel: CumulativeStressDetailViewModel
    @State private var isExplainerExpanded = false
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var contributorIconWidth: CGFloat = 20
    // Match DotLineChartView's intrinsic scaled plot height in every loading state.
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 220

    private var isRegular: Bool { sizeClass == .regular }

    init(stressScore: CumulativeStressScore, scoreRefreshService: ScoreRefreshService? = nil) {
        self.stressScore = stressScore
        self.scoreRefreshService = scoreRefreshService
        _viewModel = State(initialValue: CumulativeStressDetailViewModel(scoreRefreshService: scoreRefreshService))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                if isRegular && !dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .top, spacing: DS.Spacing.xl) {
                        scoreHero.frame(maxWidth: .infinity)
                        insightSection.frame(maxWidth: .infinity)
                    }
                } else {
                    scoreHero
                    insightSection
                }
                if !stressScore.contributions.isEmpty {
                    StandardCard { contributorsView }
                }
                CumulativeStressLevelGuide(currentLevel: stressScore.level)
                trendCard
                if !viewModel.highlights.isEmpty { highlights }
                explanation
            }
            .frame(maxWidth: DS.Layout.rootContentMaxWidth)
            .padding(isRegular ? DS.Spacing.xxl : DS.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("cumulative-stress-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Cumulative Stress")
        .navigationBarTitleDisplayMode(.large)
        .task {
            viewModel.configure(stressScore: stressScore)
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
                .accessibilityIdentifier("stress-period-picker")
                .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)

                HStack(spacing: DS.Spacing.xs) {
                    Button { viewModel.stepVisiblePeriod(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Previous period")
                    .accessibilityIdentifier("stress-period-previous")
                    .disabled(!viewModel.canStepBackward)
                    Text(viewModel.visibleRangeLabel)
                        .font(.subheadline.weight(.medium))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("score-detail-chart-visible-range")
                    Button { viewModel.stepVisiblePeriod(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Next period")
                    .accessibilityIdentifier("stress-period-next")
                    .disabled(!viewModel.canStepForward)
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.sandColor)

                chart
                if let summary = viewModel.summaryStats {
                    Divider()
                    visibleSummary(summary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stress-trend-card")
    }

    private var trendTitle: some View {
        Label("Cumulative Stress Trend", systemImage: "chart.xyaxis.line")
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
                .background(viewModel.showTrendLine ? theme.accentColor.opacity(0.12) : .clear, in: Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(viewModel.showTrendLine ? theme.accentColor : .secondary)
        .accessibilityIdentifier("score-chart-trend-toggle")
        .accessibilityValue(viewModel.showTrendLine ? Text("On") : Text("Off"))
        .sensoryFeedback(.selection, trigger: viewModel.showTrendLine)
    }

    private var chart: some View {
        Group {
            if let error = viewModel.loadError {
                VStack(spacing: DS.Spacing.md) {
                    Text(error).font(.subheadline).foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("stress-history-error")
                    Button("Try Again") { Task { await viewModel.loadData() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("stress-history-retry")
                }
                .frame(maxWidth: .infinity, minHeight: chartHeight)
            } else if viewModel.isLoading && viewModel.chartData.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: chartHeight)
            } else if viewModel.chartData.isEmpty {
                ScoreDetailEmptyState(chartHeight: chartHeight)
            } else {
                DotLineChartView(
                    data: viewModel.chartData, baseline: 50, yAxisLabel: "Score",
                    timePeriod: viewModel.selectedPeriod, tintColor: stressScore.level.color,
                    trendLine: viewModel.trendLineData, scrollDomain: viewModel.scrollDomain,
                    scrollPosition: $viewModel.scrollPosition
                )
                // Let the chart own its scaled height so AX content cannot overlap controls.
                .overlay {
                    ChartUITestSurface(identifier: "detail-chart-surface", label: "Cumulative Stress Detail Chart",
                                       value: viewModel.visibleRangeLabel)
                }
                .chartSelectionUITestProbe("visible-points:\(viewModel.visibleChartPointCount)",
                                           identifier: "stress-history-probe")
            }
        }
        .id(viewModel.selectedPeriod)
        .transition(.opacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: viewModel.selectedPeriod)
    }

    private func visibleSummary(_ summary: MetricSummary) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Period Summary").font(.caption).foregroundStyle(DS.Color.textSecondary)
            if dynamicTypeSize.isAccessibilitySize {
                summaryItems(summary)
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.md) { summaryItems(summary) }
            }
            if let change = summary.changePercentage, change.isFinite {
                Label {
                    Text("\(abs(change).formattedWithSeparator())%")
                } icon: {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(change == 0 ? DS.Color.textSecondary : change > 0 ? DS.Color.negative : DS.Color.positive)
                .accessibilityLabel("Compared with previous period")
                .accessibilityValue(Text("\(change.formattedWithSeparator())%"))
                .accessibilityIdentifier("stress-summary-change")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("stress-visible-summary")
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
                .accessibilityIdentifier("stress-summary-\(identifier)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Highlights").font(.subheadline.weight(.semibold))
            ForEach(viewModel.highlights) { highlight in
                InlineCard {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: highlight.type == .high ? "arrow.up.circle.fill"
                                  : highlight.type == .low ? "arrow.down.circle.fill" : "chart.line.uptrend.xyaxis")
                                .foregroundStyle(highlight.type == .high ? DS.Color.negative
                                                 : highlight.type == .low ? DS.Color.positive : DS.Color.textSecondary)
                            Text(highlight.label).font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                            Text(highlight.value.formattedWithSeparator()).font(.subheadline.bold().monospacedDigit())
                        }
                        if viewModel.selectedPeriod == .day {
                            Text(highlight.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                                .font(.caption).foregroundStyle(DS.Color.textSecondary)
                        } else {
                            Text(highlight.date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption).foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var explanation: some View {
        StandardCard {
            DisclosureGroup(isExpanded: $isExplainerExpanded) {
                CumulativeStressExplainerSection(isEmbedded: true, score: stressScore)
                    .padding(.top, DS.Spacing.md)
            } label: {
                Label {
                    Text("How Stress Score Works")
                        .accessibilityIdentifier("stress-score-explainer")
                } icon: {
                    Image(systemName: "info.circle.fill")
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44, alignment: .leading)
            }
            .tint(theme.sandColor)
        }
    }

    // MARK: - Subviews

    private var scoreHero: some View {
        CumulativeStressDetailHeader(score: stressScore, guideMessage: guideMessage)
    }

    private var guideMessage: String {
        switch stressScore.level {
        case .low:
            String(localized: "Your stress levels are well-managed. Keep up your healthy habits.")
        case .moderate:
            String(localized: "Stress is at a manageable level. Monitor your sleep and recovery.")
        case .elevated:
            String(localized: "Accumulated stress is building. Consider extra recovery time.")
        case .high:
            String(localized: "High stress detected. Prioritize rest and reduce training intensity.")
        }
    }

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: isRegular ? DS.Spacing.md : DS.Spacing.sm) {
            Text("Stress Insight")
                .font(isRegular ? .headline : .subheadline)
                .fontWeight(.semibold)

            InlineCard {
                HStack(alignment: .top, spacing: isRegular ? DS.Spacing.lg : DS.Spacing.md) {
                    Image(systemName: stressScore.level.iconName)
                        .font(isRegular ? .title : .title2)
                        .foregroundStyle(stressScore.level.color)
                        .frame(width: isRegular ? 36 : 32)

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(insightInterpretation)
                            .font(isRegular ? .body : .subheadline)
                            .fontWeight(.medium)

                        Text(insightGuidance)
                            .font(isRegular ? .subheadline : .caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var insightInterpretation: String {
        switch stressScore.level {
        case .low: String(localized: "Your body is well-recovered")
        case .moderate: String(localized: "Stress is within normal range")
        case .elevated: String(localized: "Stress has been accumulating")
        case .high: String(localized: "Significant stress buildup detected")
        }
    }

    private var insightGuidance: String {
        switch stressScore.level {
        case .low:
            String(localized: "Great time for high-intensity training. Your recovery indicators show consistent patterns across HRV, sleep, and activity.")
        case .moderate:
            String(localized: "Maintain your current routine. Pay attention to sleep consistency to keep stress from climbing further.")
        case .elevated:
            String(localized: "Consider adding extra recovery days. Focus on maintaining consistent sleep timing and reducing training volume temporarily.")
        case .high:
            String(localized: "Prioritize rest over performance. Reduce training intensity, maintain strict sleep schedules, and consider active recovery only.")
        }
    }

    private var contributorsView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Contributing Factors").font(.subheadline.weight(.semibold))
            ForEach(stressScore.contributions) { contribution in
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(alignment: .top, spacing: DS.Spacing.md) {
                        Image(systemName: contribution.factor.iconName)
                            .font(.title3)
                            .foregroundStyle(contribution.factor.color)
                            .frame(width: contributorIconWidth, height: contributorIconWidth)
                            .padding(DS.Spacing.sm)
                            .background(contribution.factor.color.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                            .accessibilityIdentifier("stress-contribution-icon-\(contribution.factor.rawValue)")
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            if dynamicTypeSize.isAccessibilitySize {
                                Text(contribution.factor.displayName).font(.subheadline.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                contributorScore(contribution)
                            } else {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(contribution.factor.displayName).font(.subheadline.weight(.semibold))
                                    Spacer(minLength: DS.Spacing.sm)
                                    contributorScore(contribution)
                                }
                            }
                            Text(contribution.detail).font(.caption).foregroundStyle(DS.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if contribution.rawScore.isFinite, (0...100).contains(contribution.rawScore) {
                        ProgressView(value: contribution.rawScore, total: 100)
                            .tint(contribution.factor.color)
                            .accessibilityLabel(contribution.factor.displayName)
                            .accessibilityValue(Text("\(Int(contribution.rawScore.rounded())) of 100"))
                            .accessibilityIdentifier("stress-contribution-progress-\(contribution.factor.rawValue)")
                    }
                    if let weight = stressScore.effectiveContributionWeights?[contribution.id] {
                        Text("\(Int((weight * 100).rounded()))% applied")
                            .font(.caption.weight(.medium)).foregroundStyle(DS.Color.textSecondary)
                            .accessibilityIdentifier("stress-contribution-weight-\(contribution.factor.rawValue)")
                    }
                }
                if contribution.id != stressScore.contributions.last?.id { Divider() }
            }
        }
    }

    private func contributorScore(_ contribution: CumulativeStressScore.Contribution) -> some View {
        Text(contribution.rawScore.isFinite && (0...100).contains(contribution.rawScore)
             ? contribution.rawScore.formattedWithSeparator(fractionDigits: 0) : "—")
            .font(.title3.bold().monospacedDigit())
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("stress-contribution-score-\(contribution.factor.rawValue)")
    }

}
