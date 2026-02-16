import SwiftUI

/// Detail view for the Condition Score.
/// Shows score ring, trend chart, summary, insight, and score explainer.
struct ConditionScoreDetailView: View {
    let score: ConditionScore

    @State private var viewModel = ConditionScoreDetailViewModel()
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                // Hero: Score ring + status
                scoreHero

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
                StandardCard {
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
                .animation(DS.Animation.snappy, value: viewModel.selectedPeriod)

                // Summary stats
                if let summary = viewModel.summaryStats {
                    scoreSummary(summary)
                }

                // Insight section
                ConditionInsightSection(status: score.status)

                // Highlights
                if !viewModel.highlights.isEmpty {
                    highlightsSection
                }

                // Explainer section
                StandardCard {
                    ConditionExplainerSection()
                }
            }
            .padding()
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

    private var scoreHero: some View {
        HStack {
            Spacer()
            VStack(spacing: DS.Spacing.md) {
                ZStack {
                    ProgressRingView(
                        progress: Double(score.score) / 100.0,
                        ringColor: score.status.color,
                        lineWidth: 12,
                        size: 120
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
                    summaryItem(label: "Avg", value: String(format: "%.0f", summary.average))
                    summaryItem(label: "Min", value: String(format: "%.0f", summary.min))
                    summaryItem(label: "Max", value: String(format: "%.0f", summary.max))

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
        let arrow = isPositive ? "\u{25B2}" : "\u{25BC}"
        let color: Color = isPositive ? DS.Color.positive : DS.Color.negative

        return Text("\(arrow) \(String(format: "%.1f", abs(change)))%")
            .font(.caption2)
            .fontWeight(.medium)
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
                            Text(String(format: "%.0f", highlight.value))
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
        sizeClass == .regular ? 300 : 250
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
