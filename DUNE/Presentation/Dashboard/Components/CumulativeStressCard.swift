import SwiftUI

/// Displays the 30-day cumulative stress score with contributing factors.
struct CumulativeStressCard: View {
    let stressScore: CumulativeStressScore

    var body: some View {
        InlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                header
                scoreRow
                trendRow
                contributionRows
            }
        }
        .accessibilityIdentifier("dashboard-stress-score")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.caption2)
                .foregroundStyle(levelColor)

            Text("Cumulative Stress")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Score Row

    private var scoreRow: some View {
        HStack(spacing: DS.Spacing.md) {
            // Progress gauge
            ZStack {
                Circle()
                    .stroke(DS.Color.cardBackground, lineWidth: 6)
                    .frame(width: 48, height: 48)

                Circle()
                    .trim(from: 0, to: CGFloat(stressScore.score) / 100.0)
                    .stroke(levelColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))

                Text("\(stressScore.score)")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stressScore.level.displayName)
                    .font(.headline)
                    .foregroundStyle(levelColor)

                Text("30-day stress")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Trend

    @ViewBuilder
    private var trendRow: some View {
        switch stressScore.trend {
        case .rising:
            trendLabel(
                icon: "arrow.up.right",
                text: String(localized: "Trending up — prioritize recovery"),
                color: DS.Color.negative
            )
        case .falling:
            trendLabel(
                icon: "arrow.down.right",
                text: String(localized: "Improving — keep it up"),
                color: DS.Color.positive
            )
        case .stable:
            trendLabel(
                icon: "arrow.right",
                text: String(localized: "Stable"),
                color: DS.Color.textSecondary
            )
        case .volatile, .insufficient:
            EmptyView()
        }
    }

    private func trendLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(color)
    }

    // MARK: - Contributing Factors

    private var contributionRows: some View {
        let topContributions = stressScore.contributions
            .sorted { $0.rawScore * $0.weight > $1.rawScore * $1.weight }
            .prefix(2)

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(topContributions)) { contribution in
                HStack(spacing: DS.Spacing.xxs) {
                    Circle()
                        .fill(contribution.factor.color)
                        .frame(width: 6, height: 6)

                    Text(contribution.detail)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Colors

    private var levelColor: Color {
        stressScore.level.color
    }

}
