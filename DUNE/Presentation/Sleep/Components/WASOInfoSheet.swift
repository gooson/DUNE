import SwiftUI

/// Explains what WASO means and how the score is calculated.
struct WASOInfoSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                explanationCard(icon: "moon.stars", title: "Definition", identifier: "sleep-waso-info-definition") {
                    Text("WASO stands for Wake After Sleep Onset. It measures the total time you spend awake after initially falling asleep, until your final awakening.")
                }
                explanationCard(icon: "applewatch", title: "How It's Measured", identifier: "sleep-waso-info-measurement") {
                    Text("Apple Watch detects awakenings during sleep using motion and heart rate sensors. Only awakenings lasting 5 minutes or longer are counted — brief stirrings are filtered out as normal sleep behavior.")
                }
                explanationCard(icon: "chart.bar", title: "Scoring", identifier: "sleep-waso-info-scoring") {
                    Text("The WASO Score (0–100) reflects how uninterrupted your sleep was. Less time awake means a higher score. This score contributes 15% to your overall Sleep Score.")
                }
                levelTableSection
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background { SheetWaveBackground().opacity(0.55) }
        .accessibilityIdentifier("sleep-waso-info-sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "info.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.heroAccent)
                    .padding(DS.Spacing.sm)
                    .background(palette.heroAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .accessibilityHidden(true)

                Text("What is WASO?")
                    .font(.title3.bold())
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("sleep-waso-info-title")

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .frame(width: 44, height: 44)
                        .background(palette.ink.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("sleep-waso-info-close")
            }

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 42))
                .foregroundStyle(palette.heroAccent)
                .frame(width: 74, height: 74)
                .background(palette.heroAccent.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay { RoundedRectangle(cornerRadius: DS.Radius.xl).strokeBorder(palette.border, lineWidth: 1) }
    }

    private func explanationCard<Content: View>(
        icon: String,
        title: LocalizedStringKey,
        identifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                sectionHeader(icon: icon, title: title)
                    .accessibilityIdentifier(identifier)
                content()
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier)-body")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var levelTableSection: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                sectionHeader(icon: "gauge.with.needle", title: "Score Guide")
                    .accessibilityIdentifier("sleep-waso-info-guide")
                VStack(spacing: 0) {
                    levelRow(label: "Excellent", range: "< 10 min", icon: "moon.stars.fill", color: DS.Color.scoreGood, identifier: "sleep-waso-info-level-excellent")
                    Divider()
                    levelRow(label: "Good", range: "10–20 min", icon: "moon.fill", color: DS.Color.scoreFair, identifier: "sleep-waso-info-level-good")
                    Divider()
                    levelRow(label: "Fair", range: "20–30 min", icon: "moon.zzz.fill", color: .orange, identifier: "sleep-waso-info-level-fair")
                    Divider()
                    levelRow(label: "Poor", range: "> 30 min", icon: "exclamationmark.circle.fill", color: DS.Color.scoreWarning, identifier: "sleep-waso-info-guide-poor")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionHeader(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.sleep)
                .frame(width: 32, height: 32)
                .background(DS.Color.sleep.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func levelRow(label: LocalizedStringKey, range: String, icon: String, color: Color, identifier: String) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    HStack(spacing: DS.Spacing.md) {
                        levelIcon(icon, color: color)
                        Text(label).font(.subheadline)
                    }
                    Text(range)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DS.Color.textSecondary)
                        .padding(.leading, 32 + DS.Spacing.md)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
                    levelIcon(icon, color: color)
                    Text(label)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: DS.Spacing.sm)
                    Text(range)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private func levelIcon(_ icon: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
        }
        .frame(width: 32)
        .accessibilityHidden(true)
    }
}

#Preview {
    WASOInfoSheet()
}
