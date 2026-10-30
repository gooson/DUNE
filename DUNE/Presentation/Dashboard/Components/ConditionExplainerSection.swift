import SwiftUI

/// Content of the Condition detail’s single native explanation disclosure.
struct ConditionExplainerSection: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .body) private var iconColumnWidth: CGFloat = 28

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            explainerItem(
                icon: "waveform.path.ecg",
                title: "HRV (Heart Rate Variability)",
                description: "Measures the variation between heartbeats. Higher HRV indicates a more flexible autonomic nervous system and better recovery."
            )
            .accessibilityIdentifier("condition-explanation-hrv")

            explainerItem(
                icon: "calendar",
                title: "Personal Baseline",
                description: "Your baseline uses recent HRV records and needs at least 7 days. Analysis follows your personal trends, not absolute values."
            )
            .accessibilityIdentifier("condition-explanation-baseline")

            explainerItem(
                icon: "chart.line.uptrend.xyaxis",
                title: "Score Calculation",
                description: "Statistically calculates where today's HRV falls relative to your baseline, converting it to a 0–100 score."
            )
            .accessibilityIdentifier("condition-explanation-score")

            explainerItem(
                icon: "heart.fill",
                title: "RHR Adjustment",
                description: "Factors in resting heart rate (RHR) changes. When HRV drops while RHR rises, fatigue signals are amplified."
            )
            .accessibilityIdentifier("condition-explanation-rhr")
        }
    }

    private func explainerItem(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: isRegular ? DS.Spacing.lg : DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundStyle(DS.Color.hrv)
                .frame(width: iconColumnWidth, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(isRegular ? .subheadline : .caption)
                    .fontWeight(.semibold)

                Text(description)
                    .font(isRegular ? .subheadline : .caption)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
