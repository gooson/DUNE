import SwiftUI

struct ProgressRingView: View {
    let progress: Double // 0.0 ... 1.0
    let ringColor: Color
    var lineWidth: CGFloat = 14
    var size: CGFloat = 160
    var useWarmGradient: Bool = false

    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme

    /// Pre-resolved gradient colors — computed once at init, not per render (P1 perf fix).
    private var gradientColors: [Color] {
        useWarmGradient
            ? Cache.accentGradientColors(base: ringColor, theme: theme)
            : [ringColor.opacity(0.6), ringColor]
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
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
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
    private enum Cache {
        static let desertAccent06 = Color("AccentColor").opacity(0.6)
        static let desertAccent08 = Color("AccentColor").opacity(0.8)
        static let oceanAccent06 = Color("OceanAccent").opacity(0.6)
        static let oceanAccent08 = Color("OceanAccent").opacity(0.8)

        static func accentGradientColors(base: Color, theme: AppTheme) -> [Color] {
            switch theme {
            case .desertWarm: [desertAccent06, base, desertAccent08]
            case .oceanCool:  [oceanAccent06, base, oceanAccent08]
            }
        }
    }
}
