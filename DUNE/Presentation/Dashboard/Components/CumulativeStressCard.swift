import SwiftUI

/// Displays the rolling cumulative stress score and its supporting evidence.
struct CumulativeStressCard: View {
    let stressScore: CumulativeStressScore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var gaugeSize: CGFloat = 82
    @ScaledMetric(relativeTo: .title) private var gaugeStrokeWidth: CGFloat = 6
    @State private var showsAnalysis = false

    var body: some View {
        StandardCard(padding: DS.Spacing.xxl) {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                header
                scoreRow
                analysis
                detailLink
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dashboard-stress-score")
    }

    private var header: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    headerTitle
                    periodLabel
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    headerTitle
                    Spacer(minLength: 0)
                    periodLabel
                }
            }
        }
    }

    private var headerTitle: some View {
        Label("Cumulative Stress", systemImage: "chart.line.uptrend.xyaxis")
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private var periodLabel: some View {
        Text("Recent records")
            .font(.caption)
            .foregroundStyle(DS.Color.textSecondary)
    }

    private var scoreRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    gauge
                    levelLabel
                }
            } else {
                HStack(alignment: .center, spacing: DS.Spacing.xl) {
                    gauge
                    levelLabel
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var gauge: some View {
        ZStack {
            Circle()
                .stroke(DS.Color.cardBackground, lineWidth: gaugeStrokeWidth)

            Circle()
                .trim(from: 0, to: CGFloat(stressScore.score) / 100)
                .stroke(levelColor, style: StrokeStyle(lineWidth: gaugeStrokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text(stressScore.score.formattedWithSeparator)
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .accessibilityIdentifier("dashboard-stress-score-value")
        }
        .frame(width: gaugeSize, height: gaugeSize)
    }

    private var levelLabel: some View {
        Text(stressScore.level.displayName)
            .font(.title2.weight(.semibold))
            .foregroundStyle(levelColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var analysis: some View {
        DisclosureGroup(isExpanded: $showsAnalysis) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                trendRow

                ForEach(stressScore.contributions.sorted {
                    $0.rawScore * $0.weight > $1.rawScore * $1.weight
                }) { contribution in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Circle()
                            .fill(contribution.factor.color)
                            .frame(width: 6, height: 6)
                            .padding(.top, DS.Spacing.xs)

                        Text(contribution.detail)
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, DS.Spacing.sm)
            .accessibilityIdentifier("dashboard-stress-contributions")
        } label: {
            Text("Analysis details")
                .font(.subheadline.weight(.medium))
                .accessibilityIdentifier("dashboard-stress-analysis-toggle")
        }
        .tint(levelColor)
    }

    @ViewBuilder
    private var trendRow: some View {
        switch stressScore.trend {
        case .rising:
            trendLabel(icon: "arrow.up.right", text: String(localized: "Trending up — prioritize recovery"), color: DS.Color.negative)
        case .falling:
            trendLabel(icon: "arrow.down.right", text: String(localized: "Improving — keep it up"), color: DS.Color.positive)
        case .stable:
            trendLabel(icon: "arrow.right", text: String(localized: "Stable"), color: DS.Color.textSecondary)
        case .volatile, .insufficient:
            EmptyView()
        }
    }

    private func trendLabel(icon: String, text: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(color)
    }

    private var detailLink: some View {
        NavigationLink(value: stressScore) {
            HStack {
                Text("Stress Details")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, DS.Spacing.sm)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(levelColor)
        .accessibilityIdentifier("dashboard-stress-details")
    }

    private var levelColor: Color { stressScore.level.color }
}

#Preview {
    NavigationStack {
        CumulativeStressCard(stressScore: CumulativeStressScore(
            score: 26,
            level: .low,
            contributions: [
                .init(factor: .hrvVariability, rawScore: 20, weight: 0.5, detail: "HRV variability 0.20"),
                .init(factor: .activityLoad, rawScore: 30, weight: 0.5, detail: "Training load is balanced")
            ],
            trend: .stable
        ))
        .padding()
    }
}
