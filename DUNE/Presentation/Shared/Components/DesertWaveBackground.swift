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

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .mask {
                if bottomFade > 0 {
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 1.0 - bottomFade),
                            .init(color: .white.opacity(0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Rectangle()
                }
            }

            if showShimmer {
                HeatShimmerView(opacity: 0.03)
            }
        }
        .allowsHitTesting(false)
        .task {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: driftDuration).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
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
        let size = CGSize(width: 390, height: 200)
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
            // Layer 1: Far — distant large dunes
            DesertDuneOverlayView(
                color: resolvedColor,
                opacity: 0.07 * scale,
                amplitude: 0.03 * scale,
                frequency: 0.8,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                skewness: 0.25,
                skewOffset: .pi / 6,
                driftDuration: 10
            )
            .frame(height: 200)

            // Layer 2: Near — foreground sand ripples
            DesertDuneOverlayView(
                color: resolvedColor,
                opacity: 0.13 * scale,
                amplitude: 0.055 * scale,
                frequency: 2.0,
                verticalOffset: 0.55,
                bottomFade: 0.4,
                skewness: 0.15,
                skewOffset: .pi / 4,
                ripple: 0.2,
                rippleFrequency: 5.0,
                driftDuration: 5,
                showShimmer: true
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

    var body: some View {
        let gradientTop = color.opacity(DS.Opacity.light)

        ZStack(alignment: .top) {
            DesertDuneOverlayView(
                color: color,
                opacity: 0.08,
                amplitude: 0.03,
                frequency: 1.2,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                skewness: 0.2,
                driftDuration: 8
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

    var body: some View {
        let gradientTop = color.opacity(DS.Opacity.light)

        ZStack(alignment: .top) {
            DesertDuneOverlayView(
                color: color,
                opacity: 0.06,
                amplitude: 0.02,
                frequency: 1.0,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                skewness: 0.2,
                driftDuration: 8
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
