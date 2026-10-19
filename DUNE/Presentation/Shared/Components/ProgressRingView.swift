import SwiftUI

struct ProgressRingView: View {
    let progress: Double // 0.0 ... 1.0
    let ringColor: Color
    var lineWidth: CGFloat = 14
    var size: CGFloat = 160
    var useWarmGradient: Bool = false
    var showsTravelingHighlight: Bool = false
    /// Arc tip color — the color at the progress endpoint.
    /// When nil, defaults to ringColor. Set to "next tier" color
    /// so the arc visually reaches toward the next level.
    var gradientTipColor: Color? = nil

    @State private var animatedProgress: Double = 0
    @State private var highlightPosition: Double = 0
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appTheme) private var theme

    /// Gradient stops — location 0 = arc start, location 1 = arc end.
    /// endAngle is scoped to progress so the gradient maps exactly to the visible arc.
    private var gradientStops: [Gradient.Stop] {
        let tip = gradientTipColor ?? ringColor
        if useWarmGradient {
            return Cache.accentGradientStops(base: ringColor, tipColor: tip, theme: theme)
        } else {
            return [
                Gradient.Stop(color: ringColor.opacity(0.6), location: 0),
                Gradient.Stop(color: ringColor, location: 0.82),
                Gradient.Stop(color: tip, location: 1)
            ]
        }
    }

    /// Arc extent in degrees — used as AngularGradient endAngle.
    /// Uses animatedProgress so gradient tracks the arc during animation.
    private var arcDegrees: Double {
        max(0.01, min(1.0, animatedProgress)) * 360
    }

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(ringColor.opacity(DS.Opacity.border), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        stops: gradientStops,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(arcDegrees)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if showsTravelingHighlight && isVisible && scenePhase == .active && !reduceMotion && animatedProgress > 0.05 {
                Circle()
                    .trim(from: 0, to: 0.035)
                    .stroke(
                        Color.white.opacity(0.95),
                        style: StrokeStyle(lineWidth: lineWidth * 0.42, lineCap: .round)
                    )
                    .shadow(color: theme.accentColor.opacity(0.85), radius: 4)
                    .rotationEffect(.degrees(-90 + highlightPosition * arcDegrees))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            isVisible = true
            animatedProgress = 0
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(DS.Animation.slow) {
                    animatedProgress = progress
                }
                startTravelingHighlight()
            }
        }
        .onDisappear {
            isVisible = false
            highlightPosition = 0
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isVisible && !reduceMotion {
                startTravelingHighlight()
            } else {
                highlightPosition = 0
            }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                highlightPosition = 0
                animatedProgress = progress
            } else {
                startTravelingHighlight()
            }
        }
        .onChange(of: progress) { _, newValue in
            if reduceMotion {
                animatedProgress = newValue
            } else {
                withAnimation(DS.Animation.emphasize) {
                    animatedProgress = newValue
                }
            }
        }
    }

    private func startTravelingHighlight() {
        guard showsTravelingHighlight else { return }
        highlightPosition = 0
        withAnimation(.linear(duration: 5).repeatForever(autoreverses: false)) {
            highlightPosition = 1
        }
    }

    // Correction #83 — static color caching for accent gradient (per-theme)
    // endAngle is scoped to animatedProgress, so locations 0–1 map to the visible arc only.
    // Note: Gradient.Stop arrays are lightweight value types; per-frame allocation is acceptable
    // because base/tipColor vary per caller, making full static caching impractical.
    private enum Cache {
        // Ocean Cool
        static let oceanAccent06 = Color("OceanAccent").opacity(0.6)
        // Forest Green
        static let forestAccent06 = Color("ForestAccent").opacity(0.6)
        // Sakura Calm
        static let sakuraAccent06 = Color("SakuraAccent").opacity(0.6)
        // Arctic Dawn
        static let arcticAccent06 = Color("ArcticAccent").opacity(0.6)
        // Solar Pop
        static let solarAccent06 = Color("SolarAccent").opacity(0.6)
        static let lilyGlint = Color("LilyAccent").opacity(0.64)

        static func accentGradientStops(base: Color, tipColor: Color, theme: AppTheme) -> [Gradient.Stop] {
            switch theme {
            case .desertWarm:
                // Dark shadow → status color (desert warmth at arc start)
                return [
                    .init(color: base.opacity(0.3), location: 0),
                    .init(color: base.opacity(0.8), location: 0.2),
                    .init(color: base, location: 0.78),
                    .init(color: base.exposureAdjust(1.1), location: 0.88),
                    .init(color: tipColor.exposureAdjust(1.2), location: 0.93),
                    .init(color: tipColor.exposureAdjust(0.2), location: 1)
                ]
            case .oceanCool:
                return [
                    .init(color: oceanAccent06, location: 0),
                    .init(color: base, location: 0.82),
                    .init(color: tipColor, location: 1)
                ]
            case .forestGreen:
                return [
                    .init(color: forestAccent06, location: 0),
                    .init(color: base, location: 0.82),
                    .init(color: tipColor, location: 1)
                ]
            case .sakuraCalm:
                return [
                    .init(color: sakuraAccent06, location: 0),
                    .init(color: base, location: 0.82),
                    .init(color: tipColor, location: 1)
                ]
            case .arcticDawn:
                return [
                    .init(color: arcticAccent06, location: 0),
                    .init(color: base, location: 0.82),
                    .init(color: tipColor, location: 1)
                ]
            case .contourAtlas:
                return [
                    .init(color: base, location: 0),
                    .init(color: base, location: 0.82),
                    .init(color: tipColor, location: 1)
                ]
            case .solarPop:
                return [
                    .init(color: solarAccent06, location: 0),
                    .init(color: base, location: 0.82),
                    .init(color: tipColor, location: 1)
                ]
            case .waterLilies:
                return [
                    .init(color: base.opacity(0.75), location: 0),
                    .init(color: base, location: 0.86),
                    .init(color: lilyGlint, location: 0.93),
                    .init(color: tipColor, location: 1)
                ]
            }
        }
    }
}

/// The 4-tab hero ring keeps the same geometry and numeric hierarchy as Today.
struct TabHeroScoreRing: View {
    let progress: Double
    let value: String
    let caption: LocalizedStringKey
    let ringColor: Color
    let highlightColor: Color
    let tipColor: Color
    let trackColor: Color
    let textColor: Color
    let secondaryTextColor: Color
    let accessibilityLabel: LocalizedStringKey
    let accessibilityIdentifier: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor.opacity(0.3), lineWidth: 11)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.55), ringColor, highlightColor, tipColor],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: highlightColor.opacity(reduceMotion ? 0 : 0.4), radius: 5)
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(caption)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(secondaryTextColor)
            }
            .foregroundStyle(textColor)
        }
        .frame(width: 124, height: 124)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

// MARK: - All-Levels Preview

#Preview("Ring Gradient — All Levels") {
    let levels: [(score: Int, status: ConditionScore.Status)] = [
        (10, .warning),
        (19, .warning),
        (20, .tired),
        (30, .tired),
        (39, .tired),
        (40, .fair),
        (50, .fair),
        (59, .fair),
        (60, .good),
        (70, .good),
        (79, .good),
        (80, .excellent),
        (90, .excellent),
        (95, .excellent),
        (100, .excellent)
    ]

    ScrollView {
        VStack(spacing: 24) {
            ForEach(levels, id: \.score) { level in
                HStack(spacing: 16) {
                    ProgressRingView(
                        progress: Double(level.score) / 100.0,
                        ringColor: level.status.color,
                        lineWidth: 10,
                        size: 80,
                        useWarmGradient: true,
                        gradientTipColor: level.status.nextTierColor
                    )

                    VStack(alignment: .leading) {
                        Text("\(level.score) — \(level.status.label)")
                            .font(.headline)
                        Text("ring: \(level.status.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("tip: \(nextTierLabel(level.status))")
                            .font(.caption)
                            .foregroundStyle(level.status.nextTierColor)
                    }

                    Spacer()
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color(white: 0.12))
    .preferredColorScheme(.dark)
}

private func nextTierLabel(_ status: ConditionScore.Status) -> String {
    status.nextTierStatus.rawValue
}

private extension ConditionScore.Status {
    /// The status tier this score is heading toward (for preview label derivation).
    var nextTierStatus: ConditionScore.Status {
        switch self {
        case .warning:   .tired
        case .tired:     .fair
        case .fair:      .good
        case .good:      .excellent
        case .excellent: .excellent
        }
    }
}
