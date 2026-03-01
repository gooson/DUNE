import SwiftUI

/// General explanation of how the fatigue scoring algorithm works.
/// Accessible from the body map header info button and the legend bar tap.
struct FatigueAlgorithmSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                decayModelSection
                sleepSection
                readinessSection
                levelExplanationSection
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
            Image(systemName: "function")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Fatigue Calculation")
                    .font(.headline)
                Text("Compound Fatigue Score")
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "lightbulb.fill", title: "Overview")
            Text("Analyzes the last 14 days of workout data to assess accumulated fatigue for each muscle on a 10-level scale. Factors in intensity, frequency, elapsed time, sleep quality, and biometrics.")
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    // MARK: - Decay Model

    private var decayModelSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "chart.line.downtrend.xyaxis", title: "Exponential Decay Model")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                formulaRow("Fatigue = Σ (Load × e^(-elapsed/τ))")
                bulletPoint("More recent workouts contribute more to fatigue")
                bulletPoint("Naturally decreases over time (exponential decay)")
                bulletPoint("τ (tau): Recovery rate by muscle size (large 72h, small 36h)")
            }
        }
    }

    // MARK: - Sleep

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "moon.fill", title: "Sleep Adjustment")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                bulletPoint("Recovery rate adjusted based on 7–9 hours of sleep")
                bulletPoint("Higher deep sleep & REM ratio promotes faster recovery")
                bulletPoint("Sleep deficit slows fatigue recovery (τ increases)")
                modifierExampleRow(label: "Sufficient sleep", value: "×1.15", color: .green)
                modifierExampleRow(label: "Sleep deficit", value: "×0.70", color: .orange)
            }
        }
    }

    // MARK: - Readiness

    private var readinessSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "heart.fill", title: "Bio Adjustment (HRV / RHR)")

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                bulletPoint("HRV z-score evaluates autonomic nervous system state")
                bulletPoint("Elevated RHR signals fatigue or stress")
                bulletPoint("Both metrics are combined to adjust recovery rate")
                modifierExampleRow(label: "Good HRV", value: "×1.10", color: .green)
                modifierExampleRow(label: "Elevated RHR", value: "×0.85", color: .orange)
            }
        }
    }

    // MARK: - Levels

    private var levelExplanationSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(icon: "flame.fill", title: "10-Level Fatigue Scale")

            VStack(spacing: DS.Spacing.xs) {
                levelRow(.fullyRecovered, description: "Fully recovered, max intensity training possible")
                levelRow(.wellRested, description: "Well rested, high-intensity training possible")
                levelRow(.lightFatigue, description: "Light fatigue, normal training possible")
                levelRow(.mildFatigue, description: "Mild fatigue, moderate training recommended")
                levelRow(.moderateFatigue, description: "Moderate fatigue, light training recommended")
                levelRow(.notableFatigue, description: "Notable fatigue, light training or rest")
                levelRow(.highFatigue, description: "High fatigue, active recovery recommended")
                levelRow(.veryHighFatigue, description: "Very high fatigue, rest needed")
                levelRow(.extremeFatigue, description: "Extreme fatigue, rest is essential")
                levelRow(.overtrained, description: "Overtrained, focus on recovery")
            }
        }
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

    private func formulaRow(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func bulletPoint(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.xs) {
            Text("·")
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.Color.textSecondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    private func modifierExampleRow(label: LocalizedStringKey, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
            Spacer()
            Text(value)
                .font(.caption2.weight(.medium).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, DS.Spacing.sm)
    }

    private func levelRow(_ level: FatigueLevel, description: LocalizedStringKey) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(level.color(for: colorScheme))
                .frame(width: 12, height: 12)
            Text(level.shortLabel)
                .font(.caption2.weight(.bold).monospacedDigit())
                .frame(width: 24, alignment: .leading)
            Text(description)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
            Spacer()
        }
    }
}
