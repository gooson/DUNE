import SwiftUI
import UIKit

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
/// 2. **Near** — faster, smaller dunes with sand ripple (foreground)
///
/// Includes heat shimmer texture overlay on near layer.
struct DesertTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.waveColor) private var color
    @Environment(\.appTheme) private var theme
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

    private var resolvedColor: Color {
        isWeatherActive ? atmosphere.waveColor : color
    }

    var body: some View {
        let scale = intensityScale

        ZStack(alignment: .top) {
            // Layer 1: Far — broad, smooth horizon dunes
            DesertDuneOverlayView(
                color: resolvedColor,
                opacity: 0.085 * scale,
                amplitude: 0.05 * scale,
                frequency: 0.72,
                verticalOffset: 0.37,
                bottomFade: 0.5,
                skewness: 0.2,
                skewOffset: .pi / 6,
                driftDuration: 18,
                crestColor: theme.sandColor,
                crestOpacity: 0.12 * Double(scale),
                crestWidth: 0.9
            )
            .frame(height: 200)

            // Layer 2: Near — smooth foreground dune slope
            DesertDuneOverlayView(
                color: resolvedColor,
                opacity: 0.15 * scale,
                amplitude: 0.082 * scale,
                frequency: 1.35,
                verticalOffset: 0.57,
                bottomFade: 0.4,
                skewness: 0.14,
                skewOffset: .pi / 4,
                ripple: 0,
                rippleFrequency: 5.2,
                driftDuration: 13,
                showShimmer: true,
                crestColor: theme.sandColor,
                crestOpacity: 0.20 * Double(scale),
                crestWidth: 1.35
            )
            .frame(height: 200)

            // Background gradient
            LinearGradient(
                colors: desertGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }

    private var desertGradientColors: [Color] {
        if isWeatherActive {
            return atmosphere.gradientColors
        }
        return [
            color.opacity(DS.Opacity.medium),
            DS.Color.warmGlow.opacity(DS.Opacity.subtle),
            .clear
        ]
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
                crestOpacity: 0.16,
                crestWidth: 1.0
            )
            .frame(height: 150)

            LinearGradient(
                colors: [gradientTop, .clear],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
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

            LinearGradient(
                colors: [gradientTop, .clear],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}
