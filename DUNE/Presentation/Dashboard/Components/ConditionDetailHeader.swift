import SwiftUI

/// Condition-specific composition keeps the root ring and real contribution semantics.
struct ConditionDetailHeader: View {
    let score: ConditionScore

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            hero
            if score.detail != nil || !score.contributions.isEmpty {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), alignment: .top),
                                   count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                    spacing: DS.Spacing.md
                ) {
                    ForEach(ScoreContribution.Factor.allCases, id: \.rawValue) { factor in
                        ConditionContributionTile(
                            factor: factor,
                            contribution: score.contributions.first { $0.factor == factor },
                            detail: score.detail
                        )
                    }
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Label("Condition", systemImage: score.status.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.heroAccent)
                .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                Text(score.score.formatted())
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .accessibilityIdentifier("condition-detail-score")
                    .accessibilityLabel("Condition score \(score.score), \(score.status.label)")
                status
            } else {
                HStack(spacing: DS.Spacing.lg) {
                    CompactConditionRing(
                        score: score.score,
                        ringColor: palette.heroAccent,
                        highlightColor: palette.heroHighlight,
                        tipColor: palette.heroPositive,
                        trackColor: palette.track,
                        textColor: palette.ink,
                        accessibilityLabel: "Condition score \(score.score), \(score.status.label)",
                        accessibilityIdentifier: "condition-detail-hero-ring"
                    )
                    status
                }
            }

            Text(score.detail?.evaluationDate ?? score.date,
                 format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption)
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    LinearGradient(colors: [palette.heroAccent.opacity(0.28), .clear],
                                   startPoint: .topTrailing, endPoint: .bottomLeading)
                    ConditionHeroBands()
                        .fill(palette.heroHighlight.opacity(0.08))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(palette.border, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(score.status.label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.ink)
                .accessibilityIdentifier("condition-detail-hero-status")
            Text(score.narrativeMessage)
                .font(.subheadline)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ConditionHeroBands: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.height * 0.18))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.55))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.73))
            path.addLine(to: CGPoint(x: 0, y: rect.height * 0.36))
            path.closeSubpath()
            path.move(to: CGPoint(x: 0, y: rect.height * 0.75))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.30))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.46))
            path.addLine(to: CGPoint(x: 0, y: rect.height * 0.91))
            path.closeSubpath()
        }
    }
}

private struct ConditionContributionTile: View {
    let factor: ScoreContribution.Factor
    let contribution: ScoreContribution?
    let detail: ConditionScoreDetail?

    private var value: Double? {
        switch factor {
        case .hrv: detail?.todayHRV
        case .rhr: detail?.todayRHR ?? detail?.displayRHR
        }
    }
    private var unit: String { factor == .hrv ? "ms" : "bpm" }
    private var formattedValue: String {
        value.map { "\($0.formattedWithSeparator(fractionDigits: factor == .hrv ? 1 : 0)) \(unit)" } ?? "—"
    }
    private var impactColor: Color {
        switch contribution?.impact {
        case .positive: DS.Color.positive
        case .neutral: DS.Color.caution
        case .negative: DS.Color.negative
        case nil: .secondary
        }
    }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Image(systemName: factor.iconName)
                    .font(.title2)
                    .foregroundStyle(factor.themeColor)
                    .padding(DS.Spacing.sm)
                    .background(factor.themeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .accessibilityHidden(true)
                Text(factor.displayName)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(formattedValue)
                    .font(.title3.bold().monospacedDigit())
                    .accessibilityIdentifier("condition-contribution-value-\(factor.rawValue)")
                Text(contribution?.impact.accessibilityName ?? String(localized: "Impact unavailable"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(impactColor)
                    .accessibilityIdentifier("condition-contribution-impact-\(factor.rawValue)")
                if let contribution {
                    Text(contribution.detail)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if factor == .rhr, detail?.todayRHR == nil,
                   detail?.displayRHR != nil, let date = detail?.displayRHRDate {
                    Text(date, format: .dateTime.year().month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("condition-contribution-\(factor.rawValue)")
    }
}
