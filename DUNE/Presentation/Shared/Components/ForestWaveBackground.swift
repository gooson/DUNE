import SwiftUI
import UIKit

// MARK: - Forest Wave-Specific Colors (File-Private)

/// Forest wave layer colors are only consumed by forest backgrounds.
/// Kept file-private to avoid polluting the shared AppTheme extension.
private extension AppTheme {
    var forestDeepColor: Color { Color("ForestDeep") }
    var forestMidColor: Color { Color("ForestMid") }
    var forestMistColor: Color { Color("ForestMist") }
}

// MARK: - Forest Wave Overlay View

/// Single animated forest silhouette layer with bokashi gradient and optional grain.
struct ForestWaveOverlayView: View {
    var color: Color
    var opacity: Double = 0.10
    var amplitude: CGFloat = 0.05
    var frequency: CGFloat = 1.5
    var verticalOffset: CGFloat = 0.5
    var bottomFade: CGFloat = 0.4
    var ruggedness: CGFloat = 0.3
    var treeDensity: CGFloat = 0.0
    var driftDuration: Double = 8
    var showGrain: Bool = false

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForestSilhouetteShape(
                amplitude: amplitude,
                frequency: frequency,
                phase: phase,
                verticalOffset: verticalOffset,
                ruggedness: ruggedness,
                treeDensity: treeDensity
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

            if showGrain {
                UkiyoeGrainView(opacity: 0.04)
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

// MARK: - Ukiyo-e Grain Overlay

/// Procedural wood-grain noise overlay pre-rendered to a UIImage.
/// Simulates ukiyo-e woodblock print texture.
/// Rendered once as a static constant — zero per-frame computation.
private struct UkiyoeGrainView: View {
    let opacity: Double

    /// Pre-rendered grain texture. Computed once at first access.
    /// Deterministic pseudo-random noise: product of three incommensurate sines.
    private static let grainImage: UIImage = {
        let size = CGSize(width: 390, height: 200)
        let step: CGFloat = 3
        let cols = Int(size.width / step)
        let rows = Int(size.height / step)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            for row in 0..<rows {
                for col in 0..<cols {
                    let seed = Double(row * 997 + col * 131)
                    let noise = sin(seed * 0.1) * sin(seed * 0.073) * sin(seed * 0.031)
                    let alpha = abs(noise) * 0.15
                    cgContext.setFillColor(UIColor.black.withAlphaComponent(alpha).cgColor)
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
        Image(uiImage: Self.grainImage)
            .resizable()
            .interpolation(.none)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

// MARK: - Forest Tab Background

/// Multi-layer parallax forest silhouette background for tab root screens.
///
/// Layers (back to front):
/// 1. **Far** — slowest, misty, smooth hills (distant mountains)
/// 2. **Mid** — medium speed, moderate ruggedness (mid-range forest)
/// 3. **Near** — fastest, rugged with tree silhouettes (foreground forest)
///
/// Includes ukiyo-e grain texture overlay and bokashi gradient.
struct ForestTabWaveBackground: View {
    @Environment(\.wavePreset) private var preset
    @Environment(\.appTheme) private var theme
    @Environment(\.weatherAtmosphere) private var atmosphere

    private var isWeatherActive: Bool {
        preset == .today && atmosphere != .default
    }

    /// Scale factor based on tab preset character.
    private var intensityScale: CGFloat {
        switch preset {
        case .train:    1.2   // Dense forest
        case .today:    1.0
        case .wellness: 0.8   // Gentle grove
        case .life:     0.6   // Misty meadow
        }
    }

    var body: some View {
        let scale = intensityScale

        ZStack(alignment: .top) {
            // Layer 1: Far — distant misty mountains
            ForestWaveOverlayView(
                color: theme.forestMistColor,
                opacity: 0.06 * scale,
                amplitude: 0.025 * scale,
                frequency: 1.0,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                ruggedness: 0.1,
                treeDensity: 0,
                driftDuration: 12
            )
            .frame(height: 200)

            // Layer 2: Mid — middle forest
            ForestWaveOverlayView(
                color: theme.forestMidColor,
                opacity: 0.10 * scale,
                amplitude: 0.045 * scale,
                frequency: 1.8,
                verticalOffset: 0.5,
                bottomFade: 0.4,
                ruggedness: 0.4,
                treeDensity: 0.1,
                driftDuration: 8
            )
            .frame(height: 200)

            // Layer 3: Near — foreground forest with trees
            ForestWaveOverlayView(
                color: theme.forestDeepColor,
                opacity: 0.14 * scale,
                amplitude: 0.07 * scale,
                frequency: 2.5,
                verticalOffset: 0.55,
                bottomFade: 0.4,
                ruggedness: 0.7,
                treeDensity: 0.3,
                driftDuration: 5,
                showGrain: true
            )
            .frame(height: 200)

            // Bokashi gradient overlay
            LinearGradient(
                colors: forestGradientColors,
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
        .animation(DS.Animation.atmosphereTransition, value: atmosphere)
    }

    private var forestGradientColors: [Color] {
        if isWeatherActive {
            return atmosphere.gradientColors
        }
        return [
            theme.forestMidColor.opacity(DS.Opacity.medium),
            theme.forestDeepColor.opacity(DS.Opacity.subtle),
            .clear
        ]
    }
}

// MARK: - Forest Detail Background

/// Subtler 2-layer forest silhouette for push-destination detail screens.
/// Scaled down: amplitude 50%, opacity 70%.
struct ForestDetailWaveBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            // Far
            ForestWaveOverlayView(
                color: theme.forestMistColor,
                opacity: 0.05,
                amplitude: 0.015,
                frequency: 1.0,
                verticalOffset: 0.4,
                bottomFade: 0.5,
                ruggedness: 0.1,
                treeDensity: 0,
                driftDuration: 12
            )
            .frame(height: 150)

            // Near
            ForestWaveOverlayView(
                color: theme.forestDeepColor,
                opacity: 0.10,
                amplitude: 0.035,
                frequency: 2.0,
                verticalOffset: 0.55,
                bottomFade: 0.5,
                ruggedness: 0.5,
                treeDensity: 0.2,
                driftDuration: 5
            )
            .frame(height: 150)

            LinearGradient(
                colors: [theme.forestMidColor.opacity(DS.Opacity.light), .clear],
                startPoint: .top,
                endPoint: DS.Gradient.tabBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Forest Sheet Background

/// Lightest single-layer forest silhouette for sheet/modal presentations.
/// Minimal ruggedness, no grain.
struct ForestSheetWaveBackground: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack(alignment: .top) {
            ForestWaveOverlayView(
                color: theme.forestMidColor,
                opacity: 0.08,
                amplitude: 0.025,
                frequency: 1.5,
                verticalOffset: 0.5,
                bottomFade: 0.5,
                ruggedness: 0.3,
                treeDensity: 0,
                driftDuration: 8
            )
            .frame(height: 120)

            LinearGradient(
                colors: [theme.forestMidColor.opacity(DS.Opacity.light), .clear],
                startPoint: .top,
                endPoint: DS.Gradient.sheetBackgroundEnd
            )
        }
        .ignoresSafeArea()
    }
}
