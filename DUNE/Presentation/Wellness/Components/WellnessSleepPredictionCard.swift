import SwiftUI

struct WellnessSleepPredictionCard: View {
    let prediction: SleepQualityPrediction?

    @State private var showsFactors = false
    @Environment(\.appTheme) private var theme

    private var ink: Color { theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor }
    private var muted: Color { theme == .desertWarm ? DesertPalette.muted : theme.directionPreviewTextColor.opacity(0.74) }

    var body: some View {
        StandardCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if let prediction {
                    NavigationLink(value: SleepPredictionDestination()) {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            CardNavigationHeader(chevronColor: ink) {
                                Text("Tonight's Sleep")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(ink)
                            }
                            predictionContent(prediction)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CardNavigationButtonStyle())
                    .accessibilityIdentifier("wellness-sleep-prediction-detail-link")
                    if !prediction.factors.isEmpty {
                        Button {
                            withAnimation(DS.Animation.standard) { showsFactors.toggle() }
                        } label: {
                            HStack {
                                Text("Prediction factors")
                                Spacer(minLength: DS.Spacing.sm)
                                Image(systemName: showsFactors ? "chevron.up" : "chevron.down")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ink)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("wellness-prediction-factors-disclosure")
                        if showsFactors {
                            ForEach(prediction.factors, id: \.type) { factor in
                                Text(factor.detail)
                                    .font(.caption)
                                    .foregroundStyle(muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } else {
                    Text("Tonight's Sleep")
                        .font(.headline.weight(.semibold)).foregroundStyle(ink)
                    Text("Sleep a few nights to see your sleep quality prediction.")
                        .font(.subheadline).foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("wellness-sleep-prediction-card")
    }

    private func predictionContent(_ prediction: SleepQualityPrediction) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                Text(prediction.predictedScore.formatted())
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(ink)
                Text(prediction.outlook.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink)
            }
            Text(prediction.outlook.guideMessage)
                .font(.subheadline).foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(prediction.confidence.displayName)
                .font(.caption).foregroundStyle(muted)
            if let tip = prediction.tips.first {
                Text(tip)
                    .font(.caption).foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        WellnessSleepPredictionCard(prediction: nil).padding()
    }
}
