import SwiftUI

/// Expandable section explaining how the cumulative stress score is calculated.
struct CumulativeStressExplainerSection: View {
    var isEmbedded = false
    var score: CumulativeStressScore? = nil

    @State private var isExpanded = false
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        if isEmbedded {
            explainerContent
        } else {
            DisclosureGroup(isExpanded: $isExpanded) {
                explainerContent.padding(.top, DS.Spacing.md)
            } label: {
                Label("How Stress Score Works", systemImage: "info.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44, alignment: .leading)
            }
            .tint(theme.sandColor)
        }
    }

    private var explainerContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            explainerItem(
                icon: "chart.line.uptrend.xyaxis",
                title: "What is Cumulative Stress?",
                description: "A 30-day composite indicator that tracks how much physiological stress your body has accumulated from HRV variability, sleep patterns, and training load."
            )
            Text("Stress Components").font(.subheadline.weight(.semibold))
            Text("Base weights apply when all three factors are available. Missing factors are excluded from the applied weights.")
                .font(.caption).foregroundStyle(DS.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            explainerItem(
                icon: "waveform.path.ecg",
                title: "HRV Variability (40%)",
                description: "Measures day-to-day fluctuation in your HRV. High variability suggests your autonomic nervous system is under inconsistent stress.",
                factor: .hrvVariability
            )
            Divider()
            explainerItem(
                icon: "moon.fill",
                title: "Sleep Consistency (35%)",
                description: "Evaluates regularity of your sleep patterns. Irregular sleep timing disrupts circadian rhythm and increases physiological stress.",
                factor: .sleepConsistency
            )
            Divider()
            explainerItem(
                icon: "figure.run",
                title: "Activity Load (25%)",
                description: "Compares recent training volume to your chronic baseline. Both overtraining and sudden detraining contribute to stress accumulation.",
                factor: .activityLoad
            )
        }
    }

    private func explainerItem(
        icon: String, title: LocalizedStringKey, description: LocalizedStringKey,
        factor: CumulativeStressScore.Contribution.Factor? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: isRegular ? DS.Spacing.lg : DS.Spacing.md) {
            Image(systemName: icon)
                .font(isRegular ? .title3 : .body)
                .foregroundStyle(factor?.color ?? DS.Color.hrv)
                .frame(width: isRegular ? 28 : 24, alignment: .center)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(isRegular ? .subheadline : .caption)
                    .fontWeight(.semibold)

                Text(description)
                    .font(isRegular ? .subheadline : .caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let factor, let contribution = score?.contributions.first(where: { $0.factor == factor }),
                   contribution.rawScore.isFinite, (0...100).contains(contribution.rawScore) {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                        Text(contribution.rawScore.formattedWithSeparator(fractionDigits: 0))
                            .font(.title3.bold().monospacedDigit())
                            .accessibilityLabel("Current score \(Int(contribution.rawScore.rounded()))")
                            .accessibilityIdentifier("stress-explainer-score-\(factor.rawValue)")
                        if let weight = score?.effectiveContributionWeights?[contribution.id] {
                            Text("\(Int((weight * 100).rounded()))% applied")
                                .font(.caption).foregroundStyle(DS.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}
