import SwiftUI

/// Expandable section explaining how the cumulative stress score is calculated.
struct CumulativeStressExplainerSection: View {
    @State private var isExpanded = false
    @Environment(\.appTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(DS.Animation.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(DS.Color.textSecondary)
                    Text("How Stress Score Works")
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

            if isExpanded {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    explainerItem(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "What is Cumulative Stress?",
                        description: "A 30-day composite indicator that tracks how much physiological stress your body has accumulated from HRV variability, sleep patterns, and training load."
                    )

                    explainerItem(
                        icon: "waveform.path.ecg",
                        title: "HRV Variability (40%)",
                        description: "Measures day-to-day fluctuation in your HRV. High variability suggests your autonomic nervous system is under inconsistent stress."
                    )

                    explainerItem(
                        icon: "moon.fill",
                        title: "Sleep Consistency (35%)",
                        description: "Evaluates regularity of your sleep patterns. Irregular sleep timing disrupts circadian rhythm and increases physiological stress."
                    )

                    explainerItem(
                        icon: "figure.run",
                        title: "Activity Load (25%)",
                        description: "Compares recent training volume to your chronic baseline. Both overtraining and sudden detraining contribute to stress accumulation."
                    )
                }
                .padding(.top, DS.Spacing.md)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
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
