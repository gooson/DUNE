import SwiftUI

/// Explanation of how weekly training volume is calculated and displayed.
/// Accessible from the volume mode info button and the volume legend tap.
struct VolumeAlgorithmSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                headerSection
                overviewSection
                calculationSection
                levelSection
                tipsSection
                VolumeLegendView()
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
            Image(systemName: "chart.bar.fill")
                .font(.title3)
                .foregroundStyle(DS.Color.activity)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("Weekly Training Volume")
                    .font(.headline)
                Text("Weekly Training Volume")
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
                bulletPoint("Secondary: Half the set count is credited (minimum 1 set)")
                bulletPoint("Compound exercises (e.g., Squat) credit multiple muscles simultaneously")

                formulaRow("Volume = Σ (Primary sets) + Σ (Secondary sets ÷ 2)")
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

    private func sectionHeader(icon: String, title: LocalizedStringKey) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func formulaRow(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .padding(DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.xs) {
            Text("·")
                .font(.caption.weight(.bold))
                .foregroundStyle(DS.Color.textSecondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(DS.Color.textSecondary)
        }
    }

    private func levelRow(_ level: VolumeIntensity) -> some View {
        HStack(spacing: DS.Spacing.sm) {
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
                .frame(width: 32, alignment: .leading)
            Text(level.description)
                .font(.caption2)
                .foregroundStyle(DS.Color.textSecondary)
            Spacer()
        }
    }
}
