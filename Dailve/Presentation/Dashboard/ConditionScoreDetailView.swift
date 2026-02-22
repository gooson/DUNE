import SwiftUI

/// Detail view for the Condition Score.
/// Shows score ring, trend chart, summary, insight, and score explainer.
struct ConditionScoreDetailView: View {
    let score: ConditionScore

    @State private var viewModel = ConditionScoreDetailViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.xl) {
                // Hero + Insight + Contributors
                if sizeClass == .regular {
                    // iPad: 2-column layout — ring left, insight+contributors right
                    HStack(alignment: .top, spacing: DS.Spacing.xxl) {
                        scoreHero
                            .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                            ConditionInsightSection(status: score.status)

                            if !score.contributions.isEmpty {
                                ScoreContributorsView(contributions: score.contributions)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // iPhone: stacked layout
                    scoreHero

                    ConditionInsightSection(status: score.status)

                    if !score.contributions.isEmpty {
                        ScoreContributorsView(contributions: score.contributions)
                    }
                }

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

                // Trend chart (natively scrollable)
                // Note: .id() forces full view recreation on period change,
                // intentionally resetting chart @State (e.g. selectedDate) for clean transition.
                StandardCard {
                    Group {
                        if viewModel.chartData.isEmpty && !viewModel.isLoading {
                            chartEmptyState
                        } else {
                            DotLineChartView(
                                data: viewModel.chartData,
                                baseline: 50,
                                yAxisLabel: "Score",
                                timePeriod: viewModel.selectedPeriod,
                                tintColor: score.status.color,
                                trendLine: viewModel.trendLineData,
                                scrollPosition: $viewModel.scrollPosition
                            )
                            .frame(height: chartHeight)
                        }
                    }
                    .id(viewModel.selectedPeriod)
                    .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)

                // Summary stats + Highlights
                if sizeClass == .regular {
                    // iPad: side-by-side
                    HStack(alignment: .top, spacing: DS.Spacing.lg) {
                        if let summary = viewModel.summaryStats {
                            scoreSummary(summary)
                                .frame(maxWidth: .infinity)
                        }
                        if !viewModel.highlights.isEmpty {
                            highlightsSection
                                .frame(maxWidth: .infinity)
                        }
                    }
                } else {
                    // iPhone: stacked
                    if let summary = viewModel.summaryStats {
                        scoreSummary(summary)
                    }
                    if !viewModel.highlights.isEmpty {
                        highlightsSection
                    }
                }

                // Explainer section
                StandardCard {
                    ConditionExplainerSection()
                }
            }
            .padding(sizeClass == .regular ? DS.Spacing.xxl : DS.Spacing.lg)
        }
        .navigationTitle("Condition Score")
        .navigationBarTitleDisplayMode(.large)
        .overlay {
            if viewModel.isLoading && viewModel.chartData.isEmpty {
                ProgressView()
            }
        }
        .task {
            viewModel.configure(score: score)
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
                .foregroundStyle(viewModel.showTrendLine ? score.status.color : .secondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(
                    Capsule()
                        .fill(viewModel.showTrendLine
                              ? score.status.color.opacity(0.12)
                              : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: viewModel.showTrendLine)
        }
    }

    // MARK: - Subviews

    private var ringSize: CGFloat { sizeClass == .regular ? 180 : 120 }
    private var ringLineWidth: CGFloat { sizeClass == .regular ? 16 : 12 }

    private var scoreHero: some View {
        HStack {
            Spacer()
            VStack(spacing: DS.Spacing.md) {
                ZStack {
                    ProgressRingView(
                        progress: Double(score.score) / 100.0,
                        ringColor: score.status.color,
                        lineWidth: ringLineWidth,
                        size: ringSize
                    )

                    VStack(spacing: DS.Spacing.xxs) {
                        Text("\(score.score)")
                            .font(DS.Typography.heroScore)
                            .fontDesign(.rounded)

                        Text(score.status.label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(score.date, format: .dateTime.month(.abbreviated).day().weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Condition score \(score.score), \(score.status.label)")
    }

    private func scoreSummary(_ summary: MetricSummary) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Period Summary")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: DS.Spacing.lg) {
                    summaryItem(label: "Avg", value: summary.average.formattedWithSeparator())
                    if sizeClass == .regular { Divider().frame(height: 24) }
                    summaryItem(label: "Min", value: summary.min.formattedWithSeparator())
                    if sizeClass == .regular { Divider().frame(height: 24) }
                    summaryItem(label: "Max", value: summary.max.formattedWithSeparator())

                    if let change = summary.changePercentage {
                        Spacer()
                        changeBadge(change)
                    }
                }
            }
        }
    }

    private func summaryItem(label: String, value: String) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
        }
    }

    private func changeBadge(_ change: Double) -> some View {
        let isPositive = change > 0
        let icon = isPositive ? "arrow.up.right" : "arrow.down.right"
        let color: Color = isPositive ? DS.Color.positive : DS.Color.negative

        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text("\(abs(change).formattedWithSeparator(fractionDigits: 1))%")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12), in: Capsule())
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Highlights")
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(viewModel.highlights) { highlight in
                InlineCard {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: highlightIcon(highlight.type))
                            .foregroundStyle(highlightColor(highlight.type))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(highlight.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(highlight.value.formattedWithSeparator())
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Spacer()

                        Text(highlight.date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var chartHeight: CGFloat {
        sizeClass == .regular ? 360 : 250
    }

    private func highlightIcon(_ type: Highlight.HighlightType) -> String {
        switch type {
        case .high:  "arrow.up.circle.fill"
        case .low:   "arrow.down.circle.fill"
        case .trend: "chart.line.uptrend.xyaxis"
        }
    }

    private func highlightColor(_ type: Highlight.HighlightType) -> Color {
        switch type {
        case .high:  DS.Color.positive
        case .low:   DS.Color.caution
        case .trend: DS.Color.hrv
        }
    }
}
