import SwiftUI

/// Expandable section explaining how the condition score is calculated.
struct ConditionExplainerSection: View {
    @State private var isExpanded = false
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Custom header (replaces DisclosureGroup for chevron direction control)
            Button {
                withAnimation(DS.Animation.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(DS.Color.textSecondary)
                    Text("How the Score Works")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.sandColor)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(DS.Animation.snappy, value: isExpanded)
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isExpanded)

            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    explainerItem(
                        icon: "waveform.path.ecg",
                        title: "HRV (Heart Rate Variability)",
                        description: "Measures the variation between heartbeats. Higher HRV indicates a more flexible autonomic nervous system and better recovery."
                    )

                    explainerItem(
                        icon: "calendar",
                        title: "Personal Baseline",
                        description: "Your baseline is set using 7 days of HRV data. Analysis is based on personal trends, not absolute values."
                    )

                    explainerItem(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Score Calculation",
                        description: "Statistically calculates where today's HRV falls relative to your baseline, converting it to a 0–100 score."
                    )

                    explainerItem(
                        icon: "heart.fill",
                        title: "RHR Adjustment",
                        description: "Factors in resting heart rate (RHR) changes. When HRV drops while RHR rises, fatigue signals are amplified."
                    )
                }
                .padding(.top, DS.Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func explainerItem(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: isRegular ? DS.Spacing.lg : DS.Spacing.md) {
            Image(systemName: icon)
                .font(isRegular ? .title3 : .body)
                .foregroundStyle(DS.Color.hrv)
                .frame(width: isRegular ? 28 : 24, alignment: .center)

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
