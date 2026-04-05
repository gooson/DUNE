import SwiftUI

/// Detail view for the Cumulative Stress Score.
/// Follows the canonical score detail layout:
/// Hero → Insight → Contributors → Level Guide → Period Picker → Chart Header
/// → DotLineChart → Summary Stats → Highlights → Component Weights → Explainer
struct CumulativeStressDetailView: View {
    let stressScore: CumulativeStressScore
    let scoreRefreshService: ScoreRefreshService?

    private enum Labels {
        static let scoreLabel = "STRESS"
    }

    @State private var viewModel: CumulativeStressDetailViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(stressScore: CumulativeStressScore, scoreRefreshService: ScoreRefreshService? = nil) {
        self.stressScore = stressScore
        self.scoreRefreshService = scoreRefreshService
        _viewModel = State(initialValue: CumulativeStressDetailViewModel(scoreRefreshService: scoreRefreshService))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // 1. Hero + Insight + Contributors
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: DS.Spacing.xxl) {
                        scoreHero
                            .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            insightSection

                            if !stressScore.contributions.isEmpty {
                                StandardCard {
                                    contributorsView
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .staggeredAppear(index: 0)
                } else {
                    scoreHero
                        .staggeredAppear(index: 0)
                    insightSection
                        .staggeredAppear(index: 1)

                    if !stressScore.contributions.isEmpty {
                        StandardCard {
                            contributorsView
                        }
                        .staggeredAppear(index: 1)
                    }
                }

                // 2. Level Guide
                CumulativeStressLevelGuide(currentLevel: stressScore.level)
                    .staggeredAppear(index: 2)

                // 3. Period Picker
                Picker("Period", selection: $viewModel.selectedPeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .sensoryFeedback(.selection, trigger: viewModel.selectedPeriod)
                .staggeredAppear(index: 3)

                // 4. Chart Header
                ScoreDetailChartHeader(
                    visibleRangeLabel: viewModel.visibleRangeLabel,
                    showTrendLine: $viewModel.showTrendLine,
                    tintColor: stressScore.level.color
                )
                .staggeredAppear(index: 4)

                // 5. Main Trend Chart
                StandardCard {
                    Group {
                        if viewModel.chartData.isEmpty && !viewModel.isLoading {
                            ScoreDetailEmptyState(chartHeight: chartHeight)
                        } else {
                            DotLineChartView(
                                data: viewModel.chartData,
                                baseline: 50,
                                yAxisLabel: "Score",
                                timePeriod: viewModel.selectedPeriod,
                                tintColor: stressScore.level.color,
                                trendLine: viewModel.trendLineData,
                                scrollDomain: viewModel.scrollDomain,
                                scrollPosition: $viewModel.scrollPosition
                            )
                            .frame(height: chartHeight)
                        }
                    }
                    .id(viewModel.selectedPeriod)
                    .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)
                .staggeredAppear(index: 5)

                // 6. Summary Stats + 7. Highlights
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: DS.Spacing.lg) {
                        if let summary = viewModel.summaryStats {
                            ScoreDetailSummaryStats(summary: summary)
                                .frame(maxWidth: .infinity)
                        }
                        if !viewModel.highlights.isEmpty {
                            ScoreDetailHighlights(highlights: viewModel.highlights)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .staggeredAppear(index: 6)
                } else {
                    if let summary = viewModel.summaryStats {
                        ScoreDetailSummaryStats(summary: summary)
                            .staggeredAppear(index: 6)
                    }
                    if !viewModel.highlights.isEmpty {
                        ScoreDetailHighlights(highlights: viewModel.highlights)
                            .staggeredAppear(index: 6)
                    }
                }

                // 8. Component Weights
                stressComposition
                    .staggeredAppear(index: 7)

                // 9. Explainer
                StandardCard {
                    CumulativeStressExplainerSection()
                }
                .staggeredAppear(index: 7)
            }
            .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
        .accessibilityIdentifier("cumulative-stress-detail-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Cumulative Stress")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading && viewModel.chartData.isEmpty {
                ProgressView()
            }
        }
        .task {
            viewModel.configure(stressScore: stressScore)
            await viewModel.loadData()
        }
    }

    // MARK: - Subviews

    private var scoreHero: some View {
        DetailScoreHero(
            score: stressScore.score,
            scoreLabel: Labels.scoreLabel,
            statusLabel: stressScore.level.displayName,
            statusIcon: stressScore.level.iconName,
            statusColor: stressScore.level.color,
            guideMessage: guideMessage
        )
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
        VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.md : DS.Spacing.sm) {
            Text("Stress Insight")
                .font(sizeClass == .regular ? .headline : .subheadline)
                .fontWeight(.semibold)

            InlineCard {
                HStack(alignment: .top, spacing: sizeClass == .regular ? DS.Spacing.lg : DS.Spacing.md) {
                    Image(systemName: stressScore.level.iconName)
                        .font(sizeClass == .regular ? .title : .title2)
                        .foregroundStyle(stressScore.level.color)
                        .frame(width: sizeClass == .regular ? 36 : 32)

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(insightInterpretation)
                            .font(sizeClass == .regular ? .body : .subheadline)
                            .fontWeight(.medium)

                        Text(insightGuidance)
                            .font(sizeClass == .regular ? .subheadline : .caption)
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
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Contributing Factors")
                .font(.subheadline.weight(.semibold))

            ForEach(stressScore.contributions) { contribution in
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: contribution.factor.iconName)
                        .font(.caption)
                        .foregroundStyle(contribution.factor.color)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(contribution.factor.displayName)
                                .font(.subheadline)

                            Spacer()

                            Text(String(format: "%.0f%%", contribution.weight * 100))
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            Text("\(Int(contribution.rawScore.rounded()))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .monospacedDigit()
                                .frame(width: 32, alignment: .trailing)
                        }

                        Text(contribution.detail)
                            .font(.caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private var stressComposition: some View {
        ScoreCompositionCard(
            title: "Stress Components",
            components: stressScore.contributions.map { contribution in
                .init(
                    label: contribution.factor.displayName,
                    weight: String(format: "%.0f%%", contribution.weight * 100),
                    score: Int(contribution.rawScore.rounded()),
                    color: contribution.factor.color
                )
            }
        )
    }

    // MARK: - Helpers

    private var chartHeight: CGFloat {
        sizeClass == .regular ? 360 : 250
    }

}
