import SwiftUI

/// Oura-style status bar rows showing what factors contributed to the condition score.
struct ScoreContributorsView: View {
    let contributions: [ScoreContribution]

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Score Contributors")
                .font(.subheadline)
                .fontWeight(.semibold)

            VStack(spacing: DS.Spacing.sm) {
                ForEach(contributions) { contribution in
                    contributorRow(contribution)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func contributorRow(_ contribution: ScoreContribution) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: contribution.factor.iconName)
                .font(.subheadline)
                .foregroundStyle(contribution.factor.themeColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack {
                    Text(contribution.factor.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text(contribution.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)
                            .frame(height: 6)

                        Capsule()
                            .fill(impactColor(contribution.impact))
                            .frame(width: barWidth(for: contribution.impact, in: geometry.size.width), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityLabel("\(contribution.factor.displayName), \(contribution.impact.rawValue), \(contribution.detail)")
    }

    private func impactColor(_ impact: ScoreContribution.Impact) -> Color {
        switch impact {
        case .positive: DS.Color.positive
        case .neutral: DS.Color.caution
        case .negative: DS.Color.negative
        }
    }

    private enum BarFraction {
        static let positive: CGFloat = 0.85
        static let neutral: CGFloat = 0.5
        static let negative: CGFloat = 0.25
    }

    private func barWidth(for impact: ScoreContribution.Impact, in totalWidth: CGFloat) -> CGFloat {
        let fraction: CGFloat = switch impact {
        case .positive: BarFraction.positive
        case .neutral: BarFraction.neutral
        case .negative: BarFraction.negative
        }
        return totalWidth * fraction
    }
}

// MARK: - ScoreContribution.Factor + Presentation

extension ScoreContribution.Factor {
    var displayName: String {
        switch self {
        case .hrv: "HRV"
        case .rhr: "Resting HR"
        }
    }

    var iconName: String {
        switch self {
        case .hrv: "waveform.path.ecg"
        case .rhr: "heart.fill"
        }
    }

    var themeColor: Color {
        switch self {
        case .hrv: DS.Color.hrv
        case .rhr: DS.Color.rhr
        }
    }
}
