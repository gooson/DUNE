import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Desert Dune Overlay View

/// Single animated desert dune layer with gradient fade and optional shimmer.
struct DesertDuneOverlayView: View {
    var color: Color
    var opacity: Double = 0.10
    var amplitude: CGFloat = 0.05
    var frequency: CGFloat = 1.5
    var verticalOffset: CGFloat = 0.5
    var bottomFade: CGFloat = 0.4
    var skewness: CGFloat = 0.25
    var skewOffset: CGFloat = .pi / 6
    var ripple: CGFloat = 0
    var rippleFrequency: CGFloat = 6.0
    var driftDuration: Double = 8
    var showShimmer: Bool = false
    var crestColor: Color? = nil
    var crestOpacity: Double = 0.18
    var crestWidth: CGFloat = 1.2

    @State private var phase: CGFloat = 0
    @Environment(\.waveReducedMotion) private var reduceMotion

    /// Ensure loop boundary continuity when ripple uses a non-1 phase multiplier (1.3).
    /// rippleDrift 1.3 (=13/10) needs 10 turns for phase 0 and target to match exactly.
    private var phaseLoopTurns: CGFloat { ripple > 0 ? 10 : 1 }
    private var phaseTarget: CGFloat { 2 * .pi * phaseLoopTurns }
    private var phaseDuration: Double { driftDuration * Double(phaseLoopTurns) }

    var body: some View {
        ZStack {
            DesertDuneShape(
                amplitude: amplitude,
                frequency: frequency,
                phase: phase,
                verticalOffset: verticalOffset,
                skewness: skewness,
                skewOffset: skewOffset,
                ripple: ripple,
                rippleFrequency: rippleFrequency
            )
            .fill(color.opacity(opacity))
            .bottomFadeMask(bottomFade)

            if let crestColor {
                ZStack {
                    // Wide translucent crest band.
                    DesertDuneShape(
                        amplitude: amplitude,
                        frequency: frequency,
                        phase: phase,
                        verticalOffset: verticalOffset,
                        skewness: skewness,
                        skewOffset: skewOffset,
                        ripple: ripple,
                        rippleFrequency: rippleFrequency
                    )
                    .stroke(
                        crestColor.opacity(crestOpacity * 0.48),
                        style: StrokeStyle(lineWidth: crestWidth * 2.6, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 1.1)

                    // Core crest highlight line.
                    DesertDuneShape(
                        amplitude: amplitude,
                        frequency: frequency,
                        phase: phase,
                        verticalOffset: verticalOffset,
                        skewness: skewness,
                        skewOffset: skewOffset,
                        ripple: ripple,
                        rippleFrequency: rippleFrequency
                    )
                    .stroke(
                        crestColor.opacity(crestOpacity),
                        style: StrokeStyle(lineWidth: crestWidth, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: 0.25)
                }
                .mask(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.95), .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.87)
                    )
                )
                .blendMode(.screen)
            }

            if showShimmer {
                HeatShimmerView(opacity: 0.03)
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion, driftDuration > 0 else { return }
            withAnimation(.linear(duration: phaseDuration).repeatForever(autoreverses: false)) {
                phase = phaseTarget
            }
        }
        .onAppear {
            guard !reduceMotion, driftDuration > 0 else { return }
            Task { @MainActor in
                phase = 0
                withAnimation(.linear(duration: phaseDuration).repeatForever(autoreverses: false)) {
                    phase = phaseTarget
                }
            }
        }
    }
}

// MARK: - Heat Shimmer Overlay

/// Procedural heat-haze noise overlay pre-rendered to a UIImage.
/// Simulates desert heat shimmer / mirage effect.
/// Rendered once as a static constant — zero per-frame computation.
private struct HeatShimmerView: View {
    let opacity: Double

    /// Pre-rendered shimmer texture. Computed once at first access.
    /// Deterministic pseudo-random noise: product of incommensurate sines.
    private static let shimmerImage: UIImage = {
        let size = CGSize(width: 400, height: 200)
        let step: CGFloat = 4
        let cols = Int(size.width / step)
        let rows = Int(size.height / step)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            for row in 0..<rows {
                for col in 0..<cols {
                    let seed = Double(row * 773 + col * 157)
                    let noise = sin(seed * 0.08) * sin(seed * 0.053) * sin(seed * 0.027)
                    let alpha = abs(noise) * 0.12
                    cgContext.setFillColor(UIColor.white.withAlphaComponent(alpha).cgColor)
                    cgContext.fill(CGRect(
                        x: CGFloat(col) * step,
                        y: CGFloat(row) * step,
                        width: step,
                        height: step
                    ))
                }
            }
        }
    }()

    var body: some View {
        Image(uiImage: Self.shimmerImage)
            .resizable()
            .interpolation(.none)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

// MARK: - Desert Tab Background

/// Multi-layer parallax sand dune background for tab root screens.
///
/// Layers (back to front):
/// 1. **Far** — slow, large dunes (distant horizon)
/// 2. **Mid** — warm, distinct ridge between horizon and foreground
/// 3. **Near** — faster, smaller dunes with sand ripple (foreground)
///
/// Includes heat shimmer texture overlay on near layer.
struct DesertTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.weatherAtmosphere) private var atmosphere

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    /// Scale factor based on tab preset character.
    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2   // Sandstorm energy
        case .today:    1.0
        case .wellness: 0.8   // Calm oasis
        case .life:     0.6   // Flat desert plain
        }
    }

    private var isDark: Bool { colorScheme == .dark }
    private var baseColor: Color {
        isDark ? Color(red: 0.110, green: 0.102, blue: 0.098)
            : Color(red: 0.988, green: 0.969, blue: 0.925)
    }

    var body: some View {
        let scale = intensityScale

        ZStack(alignment: .top) {
            baseColor

            LinearGradient(
                colors: desertGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 215)

            // Match the source SVG's 100-unit dune profile: far 45±8,
            // middle 62±10, near 76±13. The fills have no glowing crest.
            DesertDuneOverlayView(
                color: isDark ? Color(red: 0.467, green: 0.392, blue: 0.365)
                    : Color(red: 0.871, green: 0.776, blue: 0.647),
                opacity: 0.48 * scale,
                amplitude: 0.08 * scale,
                frequency: 0.72,
                verticalOffset: 0.45,
                bottomFade: 0,
                skewness: 0.2,
                skewOffset: .pi / 6,
                driftDuration: 18
            )
            .frame(height: 185)

            DesertDuneOverlayView(
                color: isWeatherActive ? atmosphere.waveColor : (isDark
                    ? Color(red: 0.584, green: 0.427, blue: 0.322)
                    : Color(red: 0.875, green: 0.682, blue: 0.471)),
                opacity: 0.48 * scale,
                amplitude: 0.10 * scale,
                frequency: 1.0,
                verticalOffset: 0.62,
                bottomFade: 0,
                skewness: 0.18,
                skewOffset: .pi / 6,
                driftDuration: 15
            )
            .frame(height: 185)

            DesertDuneOverlayView(
                color: isWeatherActive ? atmosphere.waveColor : (isDark
                    ? Color(red: 0.471, green: 0.310, blue: 0.235)
                    : Color(red: 0.796, green: 0.569, blue: 0.392)),
                opacity: 0.48 * scale,
                amplitude: 0.13 * scale,
                frequency: 1.35,
                verticalOffset: 0.76,
                bottomFade: 0,
                skewness: 0.14,
                skewOffset: .pi / 6,
                driftDuration: 13
            )
            .frame(height: 185)
        }
        .ignoresSafeArea()
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }

    private var desertGradientColors: [Color] {
        if isWeatherActive {
            return atmosphere.gradientColors
        }
        return [
            isDark ? Color(red: 0.267, green: 0.208, blue: 0.184)
                : Color(red: 0.961, green: 0.875, blue: 0.741),
            baseColor
        ]
    }
}

/// Three low dune layers at the foot of Desert Horizon's compact tab cards.
/// Uses the same geometry and opacity order as the source preview artwork.
struct DesertPreviewWave: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            DesertDuneOverlayView(
                color: isDark ? Color(red: 0.286, green: 0.239, blue: 0.200)
                    : Color(red: 0.937, green: 0.867, blue: 0.765),
                opacity: 0.55,
                amplitude: 0.08,
                frequency: 0.72,
                verticalOffset: 0.45,
                bottomFade: 0,
                skewness: 0.20,
                driftDuration: 18
            )
            DesertDuneOverlayView(
                color: isDark ? Color(red: 0.573, green: 0.420, blue: 0.298)
                    : Color(red: 0.906, green: 0.741, blue: 0.510),
                opacity: 0.55 * 0.38,
                amplitude: 0.10,
                frequency: 1.0,
                verticalOffset: 0.62,
                bottomFade: 0,
                skewness: 0.18,
                driftDuration: 15
            )
            DesertDuneOverlayView(
                color: isDark ? Color(red: 0.471, green: 0.310, blue: 0.235)
                    : Color(red: 0.796, green: 0.569, blue: 0.392),
                opacity: 0.55 * 0.24,
                amplitude: 0.13,
                frequency: 1.35,
                verticalOffset: 0.76,
                bottomFade: 0,
                skewness: 0.14,
                driftDuration: 13
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Desert Detail Background

/// Subtler single-layer desert dune for push-destination detail screens.
/// Scaled down: amplitude 50%, opacity 70%.
struct DesertDetailWaveBackground: View {
    @Environment(\.waveColor) private var color
    @Environment(\.appTheme) private var theme

    var body: some View {
        let gradientTop = color.opacity(DS.Opacity.light)

        ZStack(alignment: .top) {
            LinearGradient(
                colors: [gradientTop, .clear],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )

            DesertDuneOverlayView(
                color: color,
                opacity: 0.09,
                amplitude: 0.042,
                frequency: 1.0,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                skewness: 0.18,
                driftDuration: 16,
                crestColor: theme.sandColor,
                crestOpacity: 0.22,
                crestWidth: 1.2
            )
            .frame(height: 150)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Desert Sheet Background

/// Lightest single-layer desert dune for sheet/modal presentations.
struct DesertSheetWaveBackground: View {
    @Environment(\.waveColor) private var color
    @Environment(\.appTheme) private var theme

    var body: some View {
        let gradientTop = color.opacity(DS.Opacity.light)

        ZStack(alignment: .top) {
            LinearGradient(
                colors: [gradientTop, .clear],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )

            DesertDuneOverlayView(
                color: color,
                opacity: 0.065,
                amplitude: 0.03,
                frequency: 0.9,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                skewness: 0.16,
                driftDuration: 18,
                crestColor: theme.sandColor,
                crestOpacity: 0.12,
                crestWidth: 0.9
            )
            .frame(height: 120)
        }
        .ignoresSafeArea()
    }
}
