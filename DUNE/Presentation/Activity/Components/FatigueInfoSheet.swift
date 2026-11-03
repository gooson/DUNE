import SwiftUI

/// Transparent breakdown of how a muscle's fatigue level was calculated.
struct FatigueInfoSheet: View {
    let score: CompoundFatigueScore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                workoutContributionsSection
                sleepModifierSection
                readinessModifierSection
                resultSection
                FatigueLegendView()
                    .padding(.top, DS.Spacing.sm)
            }
            .padding(DS.Spacing.xl)
        }
        .background { SheetWaveBackground().opacity(0.55) }
        .accessibilityIdentifier("activity-fatigue-info-sheet")
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(palette.heroAccent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Fatigue Calculation")
                    .font(.headline)
                HStack(spacing: DS.Spacing.xs) {
                    Text(score.muscle.displayName)
                        .font(.subheadline)
                    Text(score.level.shortLabel)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(score.level.color(for: colorScheme).opacity(0.15), in: Capsule())
                        .foregroundStyle(score.level.color(for: colorScheme))
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(palette.ink)
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(palette.border, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-fatigue-info-header")
    }

    // MARK: - Workout Contributions

    private var workoutContributionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.bar.fill", title: "Workout Load (14 days)")

            if score.breakdown.workoutContributions.isEmpty {
                Text("No workout records")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            } else {
                ForEach(score.breakdown.workoutContributions) { contribution in
                    contributionRow(contribution)
                }

                HStack {
                    Text("Subtotal")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(score.breakdown.baseFatigue.formattedWithSeparator(fractionDigits: 2))
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                .padding(.top, DS.Spacing.xxs)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-fatigue-info-contributions")
    }

    private func contributionRow(_ contribution: WorkoutContribution) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xxs))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        return layout {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(DS.Color.activity)
                    .accessibilityHidden(true)
                Text(Self.dateFormatter.string(from: contribution.date))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DS.Color.textSecondary)
                Text(contribution.exerciseName ?? "Unknown")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: DS.Spacing.xs) }
            HStack(spacing: DS.Spacing.xxs) {
                Text(contribution.rawLoad.formattedWithSeparator(fractionDigits: 1))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DS.Color.textSecondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text(contribution.decayedLoad.formattedWithSeparator(fractionDigits: 2))
                    .font(.caption2.weight(.medium).monospacedDigit())
            }
        }
        .padding(DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    // MARK: - Sleep Modifier

    private var sleepModifierSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "moon.fill", title: "Sleep Adjustment")

            HStack {
                Text("Modifier")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                Spacer()
                Text("×\(score.breakdown.sleepModifier.formattedWithSeparator(fractionDigits: 2))")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(modifierColor(score.breakdown.sleepModifier))
            }

            if score.breakdown.sleepModifier == 1.0 {
                Text("No sleep data collected — default applied")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-fatigue-info-sleep")
    }

    // MARK: - Readiness Modifier

    private var readinessModifierSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "heart.fill", title: "Bio Adjustment")

            HStack {
                Text("Modifier")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                Spacer()
                Text("×\(score.breakdown.readinessModifier.formattedWithSeparator(fractionDigits: 2))")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(modifierColor(score.breakdown.readinessModifier))
            }

            if score.breakdown.readinessModifier == 1.0 {
                Text("No HRV/RHR data collected — default applied")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-fatigue-info-readiness")
    }

    // MARK: - Result

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Final Fatigue")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                HStack(spacing: DS.Spacing.xs) {
                    Text(score.normalizedScore.formattedWithSeparator(fractionDigits: 2))
                        .font(.subheadline.weight(.bold).monospacedDigit())
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(DS.Color.textSecondary)
                    Text(score.level.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(score.level.color(for: colorScheme))
                }
            }

            HStack {
                Text("Decay Time Constant (τ)")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
                Spacer()
                Text("\(score.breakdown.effectiveTau.formattedWithSeparator())h")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DS.Color.textSecondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity-fatigue-info-result")
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func modifierColor(_ value: Double) -> Color {
        if value > 1.0 { return .green }
        if value < 1.0 { return .orange }
        return .secondary
    }

    private enum Cache {
        static let dateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "M/d"
            return f
        }()
    }

    private static var dateFormatter: DateFormatter { Cache.dateFormatter }
}
