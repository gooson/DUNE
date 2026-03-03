import SwiftUI

/// Simplified sine-wave Shape for watchOS.
/// Pre-computes angles at init; `path(in:)` only scales — no heavy parsing per render.
struct WatchWaveShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    var phase: CGFloat
    let verticalOffset: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    private let points: [(x: CGFloat, angle: CGFloat)]
    /// Fewer samples than iOS (60 vs 120) for Watch performance.
    private static let sampleCount = 60

    init(
        amplitude: CGFloat = WatchWaveDefaults.amplitude,
        frequency: CGFloat = WatchWaveDefaults.frequency,
        phase: CGFloat = 0,
        verticalOffset: CGFloat = WatchWaveDefaults.verticalOffset
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.phase = phase
        self.verticalOffset = verticalOffset

        let count = Self.sampleCount
        var pts: [(x: CGFloat, angle: CGFloat)] = []
        pts.reserveCapacity(count + 1)
        for i in 0...count {
            let x = CGFloat(i) / CGFloat(count)
            let angle = x * frequency * 2 * .pi
            pts.append((x: x, angle: angle))
        }
        self.points = pts
    }

    func path(in rect: CGRect) -> Path {
        guard rect.width > 0, rect.height > 0 else { return Path() }

        let amp = rect.height * amplitude
        let centerY = rect.height * verticalOffset

        var path = Path()
        for (i, pt) in points.enumerated() {
            let x = pt.x * rect.width
            let y = centerY + amp * sin(pt.angle + phase)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Watch Wave Defaults

/// Watch-optimised wave parameters (smaller, subtler than iOS).
private enum WatchWaveDefaults {
    static let amplitude: CGFloat = 0.03
    static let frequency: CGFloat = 1.5
    static let verticalOffset: CGFloat = 0.6
    static let bottomFade: CGFloat = 0.5
    static let frameHeight: CGFloat = 80
}

// MARK: - Wave Background

/// Subtle animated wave background for watchOS screens.
/// Uses watch-optimised parameters (smaller frame, lower opacity).
struct WatchWaveBackground: View {
    var color: Color? = nil

    @State private var phase: CGFloat = 0
    @State private var petalPhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTheme) private var theme

    private var isSakura: Bool { theme == .sakuraCalm }
    private var isArctic: Bool { theme == .arcticDawn }
    private var isSolar: Bool { theme == .solarPop }

    var body: some View {
        let resolvedColor = color ?? theme.accentColor
        let gradientTop = resolvedColor.opacity(isSakura ? 0.22 : (isArctic ? 0.24 : (isSolar ? 0.25 : DS.Opacity.light)))
        let secondaryTop: Color = {
            if isSakura {
                return Color("SakuraIvory").opacity(0.14)
            }
            if isArctic {
                return Color("ArcticFrost").opacity(0.14)
            }
            if isSolar {
                return Color("SolarGlow").opacity(0.14)
            }
            return .clear
        }()

        ZStack(alignment: .top) {
            WatchWaveShape(phase: phase)
                .fill(resolvedColor.opacity(isSakura ? 0.26 : (isArctic ? 0.22 : (isSolar ? 0.24 : DS.Opacity.medium))))
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: WatchWaveDefaults.bottomFade),
                            .init(color: .white.opacity(0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(height: WatchWaveDefaults.frameHeight)

            LinearGradient(
                colors: [gradientTop, secondaryTop, .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )

            if isSakura {
                WatchSakuraPetalDots(phase: petalPhase, opacity: reduceMotion ? 0.14 : 0.2)
                    .frame(height: WatchWaveDefaults.frameHeight)
                    .padding(.top, 6)
            }

            if isArctic {
                WatchArcticAuroraBands(phase: petalPhase, opacity: reduceMotion ? 0.12 : 0.18)
                    .frame(height: WatchWaveDefaults.frameHeight)
                    .padding(.top, 5)
            }

            if isSolar {
                WatchSolarFlareBands(phase: petalPhase, opacity: reduceMotion ? 0.12 : 0.18)
                    .frame(height: WatchWaveDefaults.frameHeight)
                    .padding(.top, 5)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(DS.Animation.waveDrift) {
                phase = 2 * .pi
            }
            if isSakura || isArctic || isSolar {
                withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                    petalPhase = 2 * .pi
                }
            }
        }
    }
}

private struct WatchSolarFlareBands: View {
    let phase: CGFloat
    let opacity: Double

    private let seeds: [Double] = [0.11, 0.23, 0.34, 0.46, 0.58, 0.71, 0.83]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(seeds.enumerated()), id: \.offset) { idx, seed in
                let width = proxy.size.width * (0.42 + 0.34 * abs(sin(seed * 8.1)))
                let x = proxy.size.width * (0.10 + seed * 0.72)
                let y = proxy.size.height * (0.10 + 0.36 * abs(sin(seed * 5.7)))
                let dx = CGFloat(sin(phase * 0.9 + CGFloat(idx) * 0.8)) * 4.3
                let dy = CGFloat(cos(phase * 0.72 + CGFloat(idx) * 0.5)) * 2.4
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("SolarGlow").opacity(opacity),
                                Color("SolarCore").opacity(opacity * 0.95),
                                Color("SolarEmber").opacity(opacity * 0.60),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: 2.6 + CGFloat(idx % 2))
                    .rotationEffect(.degrees(-10 + Double(idx) * 3.2))
                    .position(x: x + dx, y: y + dy)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct WatchArcticAuroraBands: View {
    let phase: CGFloat
    let opacity: Double

    private let seeds: [Double] = [0.14, 0.26, 0.37, 0.51, 0.64, 0.77]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(seeds.enumerated()), id: \.offset) { idx, seed in
                let width = proxy.size.width * (0.46 + 0.28 * abs(sin(seed * 7.3)))
                let x = proxy.size.width * (0.12 + seed * 0.68)
                let y = proxy.size.height * (0.11 + 0.34 * abs(sin(seed * 5.1)))
                let dx = CGFloat(sin(phase * 0.85 + CGFloat(idx) * 0.9)) * 4.0
                let dy = CGFloat(cos(phase * 0.65 + CGFloat(idx) * 0.4)) * 2.5
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("ArcticAurora").opacity(opacity),
                                Color("ArcticFrost").opacity(opacity * 0.9),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width, height: 2.8 + CGFloat(idx % 2))
                    .rotationEffect(.degrees(-8 + Double(idx) * 3))
                    .position(x: x + dx, y: y + dy)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct WatchSakuraPetalDots: View {
    let phase: CGFloat
    let opacity: Double

    private let seeds: [Double] = [0.12, 0.23, 0.35, 0.48, 0.57, 0.67, 0.79, 0.88]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(seeds.enumerated()), id: \.offset) { idx, seed in
                let x = (0.12 + seed * 0.78) * proxy.size.width
                let y = (0.12 + abs(sin(seed * 9.0)) * 0.45) * proxy.size.height
                let dx = CGFloat(sin(phase + CGFloat(idx) * 0.7)) * 3.5
                let dy = CGFloat(cos(phase * 0.7 + CGFloat(idx) * 0.3)) * 2.8
                Circle()
                    .fill(Color("SakuraPetal").opacity(opacity))
                    .frame(width: 2.8 + CGFloat(idx % 3), height: 2.8 + CGFloat(idx % 3))
                    .position(x: x + dx, y: y + dy)
            }
        }
        .allowsHitTesting(false)
    }
}
