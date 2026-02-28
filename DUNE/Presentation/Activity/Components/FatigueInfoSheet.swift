import SwiftUI

/// Transparent breakdown of how a muscle's fatigue level was calculated.
struct FatigueInfoSheet: View {
    let score: CompoundFatigueScore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                workoutContributionsSection
                sleepModifierSection
                readinessModifierSection
                Divider()
                resultSection
                FatigueLegendView()
                    .padding(.top, DS.Spacing.sm)
            }
            .padding(DS.Spacing.xl)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)

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
            Spacer()
        }
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
    }

    private func contributionRow(_ contribution: WorkoutContribution) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(Self.dateFormatter.string(from: contribution.date))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(DS.Color.textSecondary)
                .frame(width: 45, alignment: .leading)

            Text(contribution.exerciseName ?? "Unknown")
                .font(.caption)
                .lineLimit(1)

            Spacer()

            HStack(spacing: DS.Spacing.xxs) {
                Text(contribution.rawLoad.formattedWithSeparator(fractionDigits: 1))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(DS.Color.textSecondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(contribution.decayedLoad.formattedWithSeparator(fractionDigits: 2))
                    .font(.caption2.weight(.medium).monospacedDigit())
            }
        }
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
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
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
