import SwiftUI

struct WellnessSleepPredictionCard: View {
    let prediction: SleepQualityPrediction?

    @State private var showsFactors = false
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let sleepWash = DS.Color.sleep.opacity(0.10)
    private static let sleepTrack = DS.Color.sleep.opacity(0.16)

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
                                    .accessibilityIdentifier("wellness-sleep-prediction-card")
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
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(DS.Color.sleep)
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
                        .accessibilityIdentifier("wellness-sleep-prediction-card")
                        .font(.headline.weight(.semibold)).foregroundStyle(ink)
                    Text("Sleep a few nights to see your sleep quality prediction.")
                        .font(.subheadline).foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func predictionContent(_ prediction: SleepQualityPrediction) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    nightEmblem(prediction)
                    scoreValue(prediction)
                }
            } else {
                HStack(spacing: DS.Spacing.lg) {
                    scoreValue(prediction)
                    Spacer(minLength: DS.Spacing.sm)
                    nightEmblem(prediction)
                }
            }
            scoreMeter(prediction)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    outlookLabel(prediction)
                    confidenceBadge(prediction.confidence)
                }
            } else {
                HStack(alignment: .center, spacing: DS.Spacing.sm) {
                    outlookLabel(prediction)
                    Spacer(minLength: 0)
                    confidenceBadge(prediction.confidence)
                }
            }
            Text(prediction.outlook.guideMessage)
                .font(.subheadline).foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
            if let tip = prediction.tips.first {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DS.Color.sleep)
                        .accessibilityHidden(true)
                    Text(tip)
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.md)
                .background(Self.sleepWash, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scoreValue(_ prediction: SleepQualityPrediction) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Predicted score")
                .font(.caption).foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
            Text(prediction.predictedScore.formatted())
                .font(DS.Typography.heroScore.monospacedDigit())
                .foregroundStyle(ink)
                .accessibilityIdentifier("wellness-prediction-score-value")
        }
    }

    private func nightEmblem(_ prediction: SleepQualityPrediction) -> some View {
        Image(systemName: prediction.outlook.iconName)
            .font(.system(size: 34, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(DS.Color.sleep)
            .frame(width: 72, height: 72)
            .background(Self.sleepWash, in: RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .strokeBorder(Self.sleepTrack, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private func outlookLabel(_ prediction: SleepQualityPrediction) -> some View {
        Text(prediction.outlook.displayName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func scoreMeter(_ prediction: SleepQualityPrediction) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Self.sleepTrack)
                    if prediction.predictedScore > 0 {
                        Capsule().fill(DS.Color.sleep)
                            .frame(width: proxy.size.width * CGFloat(prediction.predictedScore) / 100)
                    }
                }
            }
            .frame(height: 10)
            HStack {
                Text(0, format: .number)
                Spacer(minLength: DS.Spacing.sm)
                Text(100, format: .number)
            }
            .font(.caption2).foregroundStyle(muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Predicted score"))
        .accessibilityValue(Text(verbatim: prediction.predictedScore.formatted() + " / " + 100.formatted()))
        .accessibilityIdentifier("wellness-prediction-score-meter")
    }

    private func confidenceBadge(_ confidence: SleepQualityPrediction.Confidence) -> some View {
        let level: Int = switch confidence {
        case .low: 1
        case .medium: 2
        case .high: 3
        }
        return HStack(alignment: .center, spacing: DS.Spacing.sm) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3) { index in
                    Capsule().fill(index < level ? DS.Color.sleep : Self.sleepTrack)
                        .frame(width: 4, height: CGFloat(6 + index * 3))
                }
            }
            .accessibilityHidden(true)
            Text(confidence.displayName)
                .font(.caption.weight(.medium)).foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(Self.sleepWash, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("wellness-prediction-confidence")
    }
}

#Preview {
    NavigationStack {
        WellnessSleepPredictionCard(prediction: nil).padding()
    }
}
