import SwiftUI

struct ProgressRingView: View {
    let progress: Double // 0.0 ... 1.0
    let ringColor: Color
    var lineWidth: CGFloat = 14
    var size: CGFloat = 160
    var useWarmGradient: Bool = false
    /// Arc tip color — the color at the progress endpoint.
    /// When nil, defaults to ringColor. Set to "next tier" color
    /// so the arc visually reaches toward the next level.
    var gradientTipColor: Color? = nil

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        }
        .frame(width: size, height: size)
        .onAppear {
            animatedProgress = 0
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(DS.Animation.slow) {
                    animatedProgress = progress
                }
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

    // Correction #83 — static color caching for accent gradient (per-theme)
    // endAngle is scoped to animatedProgress, so locations 0–1 map to the visible arc only.
    // Note: Gradient.Stop arrays are lightweight value types; per-frame allocation is acceptable
    // because base/tipColor vary per caller, making full static caching impractical.
    private enum Cache {
        // Ocean Cool
        static let oceanAccent06 = Color("OceanAccent").opacity(0.6)
        // Forest Green
        static let forestAccent06 = Color("ForestAccent").opacity(0.6)

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
            }
        }
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
