import SwiftUI

/// The same opaque score surface and ring as Today/T04, retaining stress severity semantics.
struct CumulativeStressDetailHeader: View {
    let score: CumulativeStressScore
    let guideMessage: String

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Label {
                Text("Cumulative Stress")
            } icon: {
                Image(systemName: score.level.iconName).foregroundStyle(score.level.color)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.heroAccent)
            .accessibilityAddTraits(.isHeader)

            if dynamicTypeSize.isAccessibilitySize {
                Text(score.score.formattedWithSeparator)
                    .font(.largeTitle.bold().monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .accessibilityIdentifier("stress-detail-score")
                    .accessibilityLabel("Stress score \(score.score), \(score.level.displayName)")
                status
            } else {
                HStack(spacing: DS.Spacing.lg) {
                    CompactConditionRing(
                        score: score.score, ringColor: palette.heroAccent,
                        highlightColor: palette.heroHighlight, tipColor: palette.heroPositive,
                        trackColor: palette.track, textColor: palette.ink,
                        accessibilityLabel: "Stress score \(score.score), \(score.level.displayName)",
                        accessibilityIdentifier: "stress-detail-hero-ring"
                    )
                    status
                }
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Last \(score.windowDays) days")
                Text(score.date, format: .dateTime.month(.abbreviated).day().hour().minute())
            }
            .font(.caption).foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    LinearGradient(colors: [palette.heroAccent.opacity(0.28), .clear],
                                   startPoint: .topTrailing, endPoint: .bottomLeading)
                    DesertDuneOverlayView(color: palette.heroHighlight, opacity: 0.12,
                                          amplitude: 0.12, frequency: 0.7, verticalOffset: 0.60,
                                          bottomFade: 0, driftDuration: 0,
                                          crestColor: palette.heroAccent, crestOpacity: 0.20)
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
            Text(score.level.displayName)
                .font(.title3.weight(.semibold)).foregroundStyle(palette.ink)
                .accessibilityIdentifier("stress-detail-hero-status")
            Text(guideMessage).font(.subheadline).foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
