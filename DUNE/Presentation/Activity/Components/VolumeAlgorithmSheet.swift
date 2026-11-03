import SwiftUI

/// Explanation of how weekly training volume is calculated and displayed.
/// Accessible from the volume mode info button and the volume legend tap.
struct VolumeAlgorithmSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var legendWidth: CGFloat = 320

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                explanationCard { overviewSection }
                explanationCard { calculationSection }
                explanationCard { levelSection }
                explanationCard { tipsSection }
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView(.horizontal) {
                        VolumeLegendView().accessibilityIdentifier("activity-volume-algorithm-legend").frame(minWidth: legendWidth)
                    }
                    .accessibilityIdentifier("activity-volume-algorithm-legend-scroll")
                    .padding(.top, DS.Spacing.sm)
                } else {
                    VolumeLegendView().accessibilityIdentifier("activity-volume-algorithm-legend")
                        .padding(.top, DS.Spacing.sm)
                }
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background { SheetWaveBackground().opacity(0.55) }
        .accessibilityIdentifier("activity-volume-algorithm-sheet")
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: "chart.bar.fill")
                .font(.title3)
                .foregroundStyle(palette.heroAccent)
                .padding(DS.Spacing.sm)
                .background(palette.heroAccent.opacity(0.16), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)
            Text("Weekly Training Volume")
                .font(.title3.bold())
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay { RoundedRectangle(cornerRadius: DS.Radius.lg).strokeBorder(palette.border, lineWidth: 1) }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.fill", title: "Overview")
            Text("Visualizes training volume by tallying sets performed for each muscle group over the last 7 days. Quickly see which muscles are well-trained and which need more work.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Calculation

    private var calculationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "function", title: "Calculation Method")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                bulletPoint("Primary: Full set count is credited to the muscle")
                bulletPoint("Secondary: For each record, halve the completed sets, round down, and credit at least 1 set",
                            identifier: "activity-volume-algorithm-secondary")
                bulletPoint("Compound exercises (e.g., Squat) credit multiple muscles simultaneously")

                formulaRow("Volume = Σ primary sets + Σ max(⌊secondary sets ÷ 2⌋, 1)")
                    .accessibilityIdentifier("activity-volume-algorithm-formula")
            }
        }
    }

    // MARK: - Levels

    private var levelSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.bar.xaxis", title: "5-Level Volume Scale")

            VStack(spacing: DS.Spacing.xs) {
                ForEach(VolumeIntensity.allCases, id: \.rawValue) { level in
                    levelRow(level)
                }
            }
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "sparkles", title: "Tips")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                bulletPoint("Gray muscles have not been trained this week")
                bulletPoint("Aim to color all muscles for balanced training")
                bulletPoint("Combine with Recovery mode to plan optimal training")
            }
        }
    }

    // MARK: - Helpers

    private func explanationCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func sectionHeader(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DS.Color.activity)
                .padding(DS.Spacing.sm)
                .background(DS.Color.activity.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func formulaRow(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func bulletPoint(_ text: LocalizedStringKey, identifier: String? = nil) -> some View {
        let label = Text(text)
            .font(.caption)
            .foregroundStyle(DS.Color.textSecondary)
        return HStack(alignment: .top, spacing: DS.Spacing.xs) {
            Text("·")
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.Color.textSecondary)
                .accessibilityHidden(true)
            if let identifier {
                label.accessibilityIdentifier(identifier)
            } else {
                label
            }
        }
    }

    private func levelRow(_ level: VolumeIntensity) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.sm))
        return layout {
            RoundedRectangle(cornerRadius: 2)
                .fill(level.color)
                .overlay {
                    if level == .none {
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    }
                }
                .frame(width: 12, height: 12)
            Text(level.label)
                .font(.caption2.weight(.bold).monospacedDigit())
                .fixedSize(horizontal: true, vertical: false)
            Text(level.description)
                .accessibilityIdentifier("activity-volume-algorithm-level-\(level.rawValue)")
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
