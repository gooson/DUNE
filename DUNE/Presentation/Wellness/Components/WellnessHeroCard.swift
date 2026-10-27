import SwiftUI

struct WellnessHeroCard: View {
    let score: WellnessScore?
    let sleepScore: Int?
    let conditionScore: Int?
    let bodyScore: Int?
    var hourlySparkline: HourlySparklineData?
    var sleepTrend: [SleepDailySample] = []
    var sleepMetric: HealthMetric?

    @State private var showsEvidence = false
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isWide: Bool { sizeClass == .regular && !dynamicTypeSize.isAccessibilitySize }
    private var ink: Color { theme == .desertWarm ? DesertPalette.ink : theme.directionPreviewTextColor }
    private var muted: Color { theme == .desertWarm ? DesertPalette.muted : theme.directionPreviewTextColor.opacity(0.74) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if let score {
                if isWide {
                    HStack(alignment: .top, spacing: DS.Spacing.xxl) {
                        scoreLink(score).frame(maxWidth: .infinity, alignment: .leading)
                        evidence(score).frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    scoreLink(score)
                    evidence(score)
                }
            } else {
                Text(verbatim: "WELLNESS")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(ink)
                    .accessibilityIdentifier("wellness-hero-heading")
                Text("Need More Data").font(.headline).foregroundStyle(ink)
                Text("Wear your Apple Watch tonight to start tracking your wellness score.")
                    .font(.subheadline).foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if theme == .desertWarm {
                DesertCardSurface(cornerRadius: DS.Radius.xxl)
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.xxl)
                    .fill(theme.directionPreviewBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.xxl)
                            .strokeBorder(theme.accentColor.opacity(0.25), lineWidth: 1)
                    }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if theme == .desertWarm {
                Ellipse()
                    .fill(DesertPalette.duneFar.opacity(0.12))
                    .frame(width: 200, height: 45)
                    .offset(x: 45, y: 23)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xxl))
    }

    private func scoreLink(_ score: WellnessScore) -> some View {
        NavigationLink(value: WellnessScoreDestination()) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                CardNavigationHeader(minimumHeight: 0, chevronColor: ink) {
                    Text(verbatim: "WELLNESS")
                        .font(.caption.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(ink)
                        .accessibilityIdentifier("wellness-hero-heading")
                }
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(score.score.formatted())
                            .font(.largeTitle.weight(.bold).monospacedDigit())
                            .foregroundStyle(ink)
                        Text(score.status.label).font(.headline).foregroundStyle(ink)
                        scoreRing(score)
                    }
                } else {
                    HStack(alignment: .center, spacing: DS.Spacing.lg) {
                        scoreRing(score)
                        Text(score.status.label)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Text(score.narrativeMessage)
                    .font(.subheadline).foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("wellness-hero-narrative")
                Text(score.evaluationDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption).foregroundStyle(muted)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CardNavigationButtonStyle())
        .accessibilityIdentifier("wellness-hero-score")
        .accessibilityLabel("Wellness score \(score.score), \(score.status.label)")
        .accessibilityHint("Wellness Details")
    }

    private func scoreRing(_ score: WellnessScore) -> some View {
        CompactConditionRing(
            score: score.score,
            ringColor: DS.Color.warmGlow,
            highlightColor: DS.Color.body,
            tipColor: score.status.color,
            trackColor: DS.Color.warmGlow,
            textColor: ink,
            accessibilityLabel: "Wellness score \(score.score), \(score.status.label)",
            accessibilityIdentifier: "wellness-hero-ring"
        )
    }

    private func evidence(_ score: WellnessScore) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Score evidence").font(.subheadline.weight(.semibold)).foregroundStyle(ink)
            evidenceRow("Sleep", icon: "moon.fill", value: score.sleepScore, color: DS.Color.sleep)
            evidenceRow("Condition", icon: "heart.fill", value: score.conditionScore, color: DS.Color.hrv)
            evidenceRow("Body", icon: "figure.stand", value: score.bodyScore, color: DS.Color.body)
            evidenceRow("Posture", icon: "figure.stand", value: score.postureScore, color: DS.Color.posture)
            Button {
                withAnimation(DS.Animation.standard) { showsEvidence.toggle() }
            } label: {
                HStack {
                    Text("How this score is calculated")
                    Spacer(minLength: DS.Spacing.sm)
                    Image(systemName: showsEvidence ? "chevron.up" : "chevron.down")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(ink)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("wellness-hero-evidence-disclosure")
            if showsEvidence {
                Text("Sleep 35%, Condition 30%, Body 20%, Posture 15%. Available scores are reweighted when a component is missing.")
                    .font(.caption).foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("wellness-hero-evidence-explanation")
            }
        }
        .accessibilityIdentifier("wellness-hero-evidence")
    }

    private func evidenceRow(_ title: LocalizedStringKey, icon: String, value: Int?, color: Color) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    evidenceLabel(title, icon: icon, value: value, color: color)
                    evidenceBar(value: value, color: color)
                        .frame(height: 6)
                }
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: icon).font(.caption).foregroundStyle(color).frame(width: 18)
                    Text(title).font(.caption).foregroundStyle(ink).frame(width: 72, alignment: .leading)
                    evidenceBar(value: value, color: color).frame(height: 6)
                    Text(value.map { $0.formatted() } ?? "—")
                        .font(.caption.monospacedDigit()).foregroundStyle(ink)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
    }

    private func evidenceLabel(_ title: LocalizedStringKey, icon: String, value: Int?, color: Color) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon).font(.caption).foregroundStyle(color).frame(width: 18)
            Text(title).font(.caption).foregroundStyle(ink)
            Spacer(minLength: DS.Spacing.sm)
            Text(value.map { $0.formatted() } ?? "—")
                .font(.caption.monospacedDigit()).foregroundStyle(ink)
        }
    }

    private func evidenceBar(value: Int?, color: Color) -> some View {
        GeometryReader { geometry in
            Capsule().fill(color.opacity(0.15))
                .overlay(alignment: .leading) {
                    if let value {
                        Capsule().fill(color)
                            .frame(width: geometry.size.width * CGFloat(max(0, min(100, value))) / 100)
                    }
                }
        }
    }
}

#Preview {
    NavigationStack {
        WellnessHeroCard(score: WellnessScore(score: 79, sleepScore: 83, conditionScore: 64, bodyScore: 75, postureScore: 80), sleepScore: 83, conditionScore: 64, bodyScore: 75)
            .padding()
    }
}
