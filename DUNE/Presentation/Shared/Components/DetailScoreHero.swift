import SwiftUI

/// Shared hero section for score detail views (Condition, Wellness, Training Readiness).
/// Displays a centered progress ring with score, status info, guide message, and optional sub-score badges.
struct DetailScoreHero: View {
    let score: Int
    let scoreLabel: String
    let statusLabel: String
    let statusIcon: String
    let statusColor: Color
    let guideMessage: String
    var subScores: [SubScoreBadge] = []
    var badgeText: String? = nil

    struct SubScoreBadge {
        let label: String
        let value: Int?
        let color: Color
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                ProgressRingView(
                    progress: Double(score) / 100.0,
                    ringColor: statusColor,
                    lineWidth: isRegular ? 18 : 16,
                    size: isRegular ? 180 : 140
                )

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(DS.Typography.heroScore)
                        .contentTransition(.numericText())

                    Text(scoreLabel)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                        .tracking(1)
                }
            }

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                Text(statusLabel)
                    .font(.title3.weight(.semibold))

                if let badgeText {
                    Text(badgeText)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.quaternary))
                }
            }

            Text(guideMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !subScores.isEmpty {
                HStack(spacing: DS.Spacing.lg) {
                    ForEach(subScores, id: \.label) { item in
                        subScoreBadgeView(item)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(scoreLabel.capitalized) score \(score), \(statusLabel)")
    }

    private func subScoreBadgeView(_ item: SubScoreBadge) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Text(item.value.map { "\($0)" } ?? "--")
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(item.value != nil ? item.color : .secondary)

            Text(item.label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
