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

private enum WatchArcticAuroraPalette {
    static let neonMint = Color(red: 0.52, green: 0.97, blue: 0.80)
    static let emerald = Color(red: 0.30, green: 0.91, blue: 0.66)
    static let lime = Color(red: 0.73, green: 0.98, blue: 0.52)
    static let cyan = Color(red: 0.27, green: 0.90, blue: 0.92)
    static let violet = Color(red: 0.68, green: 0.44, blue: 0.94)
    static let magenta = Color(red: 0.80, green: 0.39, blue: 0.83)
    static let champagne = Color(red: 0.95, green: 0.84, blue: 0.67)
    static let pearl = Color(red: 0.96, green: 0.93, blue: 0.84)
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

    var body: some View {
        let resolvedColor = color ?? theme.accentColor
        let baseWaveColor: Color = isArctic ? Color("ArcticDeep") : resolvedColor
        let gradientTop = (isArctic ? Color("ArcticDeep") : resolvedColor)
            .opacity(isSakura ? 0.22 : (isArctic ? 0.30 : DS.Opacity.light))
        let secondaryTop: Color = {
            if isSakura {
                return Color("SakuraIvory").opacity(0.14)
            }
            if isArctic {
                return WatchArcticAuroraPalette.neonMint.opacity(0.26)
            }
            return .clear
        }()
        let tertiaryTop: Color = isArctic ? WatchArcticAuroraPalette.violet.opacity(0.18) : .clear
        let quaternaryTop: Color = isArctic ? WatchArcticAuroraPalette.magenta.opacity(0.14) : .clear

        ZStack(alignment: .top) {
            WatchWaveShape(
                amplitude: isArctic ? 0.040 : WatchWaveDefaults.amplitude,
                frequency: isArctic ? 1.35 : WatchWaveDefaults.frequency,
                phase: phase,
                verticalOffset: isArctic ? 0.62 : WatchWaveDefaults.verticalOffset
            )
            .fill(baseWaveColor.opacity(isSakura ? 0.26 : (isArctic ? 0.30 : DS.Opacity.medium)))
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

            if isArctic {
                WatchWaveShape(
                    amplitude: 0.055,
                    frequency: 1.94,
                    phase: -phase * 0.85,
                    verticalOffset: 0.66
                )
                .fill(Color("ArcticFrost").opacity(0.15))
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.54),
                            .init(color: .white.opacity(0), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(height: WatchWaveDefaults.frameHeight + 6)
            }

            LinearGradient(
                colors: [gradientTop, secondaryTop, tertiaryTop, quaternaryTop, .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )

            if isArctic {
                WatchArcticAuroraCurtains(
                    phase: phase,
                    shimmerPhase: petalPhase,
                    opacity: reduceMotion ? 0.12 : 0.20
                )
                .frame(height: WatchWaveDefaults.frameHeight + 8)
                .padding(.top, 1)

                LinearGradient(
                    colors: [
                        .clear,
                        WatchArcticAuroraPalette.pearl.opacity(reduceMotion ? 0.10 : 0.18),
                        WatchArcticAuroraPalette.lime.opacity(reduceMotion ? 0.09 : 0.15),
                        WatchArcticAuroraPalette.cyan.opacity(reduceMotion ? 0.07 : 0.12),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 18)
                .blur(radius: 4)
                .offset(y: WatchWaveDefaults.frameHeight * 0.45)
                .blendMode(.screen)
            }

            if isSakura {
                WatchSakuraPetalDots(phase: petalPhase, opacity: reduceMotion ? 0.14 : 0.2)
                    .frame(height: WatchWaveDefaults.frameHeight)
                    .padding(.top, 6)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            if isArctic {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    phase = 2 * .pi
                }
                withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                    petalPhase = 2 * .pi
                }
                return
            }

            withAnimation(DS.Animation.waveDrift) {
                phase = 2 * .pi
            }
            if isSakura {
                withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                    petalPhase = 2 * .pi
                }
            }
        }
    }
}

private struct WatchArcticAuroraCurtains: View {
    let phase: CGFloat
    let shimmerPhase: CGFloat
    let opacity: Double

    private let seeds: [Double] = [0.12, 0.23, 0.34, 0.45, 0.58, 0.71, 0.84]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(seeds.enumerated()), id: \.offset) { idx, seed in
                    let width = 5.2 + CGFloat(idx % 3) * 1.8 + CGFloat(abs(sin(seed * 11.0))) * 1.4
                    let height = proxy.size.height * (0.58 + 0.25 * abs(sin(seed * 8.1)))
                    let x = proxy.size.width * (0.10 + seed * 0.78)
                    let y = proxy.size.height * (0.20 + 0.14 * abs(cos(seed * 6.2)))
                    let dx = CGFloat(sin(phase * 0.55 + CGFloat(idx) * 0.42)) * 1.8
                    let pulse = 0.72 + 0.28 * abs(sin(Double(shimmerPhase) + seed * 8.0))
                    let topColor = idx.isMultiple(of: 2)
                        ? WatchArcticAuroraPalette.neonMint
                        : WatchArcticAuroraPalette.violet
                    let middleColor = idx.isMultiple(of: 2)
                        ? WatchArcticAuroraPalette.emerald
                        : WatchArcticAuroraPalette.magenta
                    let lowerColor = idx.isMultiple(of: 2)
                        ? WatchArcticAuroraPalette.cyan
                        : WatchArcticAuroraPalette.champagne

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    topColor.opacity(opacity * 1.05 * pulse),
                                    middleColor.opacity(opacity * 0.92 * pulse),
                                    lowerColor.opacity(opacity * 0.82 * pulse),
                                    WatchArcticAuroraPalette.pearl.opacity(opacity * 0.72 * pulse),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: width, height: height)
                        .rotationEffect(.degrees(-2 + Double(idx) * 0.7))
                        .position(x: x + dx, y: y)
                        .blur(radius: idx.isMultiple(of: 2) ? 0.7 : 1.1)
                        .hueRotation(.degrees(idx.isMultiple(of: 3) ? -4 : 5))
                        .saturation(1.12)
                        .blendMode(.screen)
                }

                RadialGradient(
                    colors: [WatchArcticAuroraPalette.champagne.opacity(opacity * 0.44), .clear],
                    center: UnitPoint(x: 0.74, y: 0.08),
                    startRadius: 2,
                    endRadius: 70
                )

                RadialGradient(
                    colors: [WatchArcticAuroraPalette.neonMint.opacity(opacity * 0.52), .clear],
                    center: UnitPoint(x: 0.24, y: 0.02),
                    startRadius: 2,
                    endRadius: 85
                )

                RadialGradient(
                    colors: [WatchArcticAuroraPalette.violet.opacity(opacity * 0.42), .clear],
                    center: UnitPoint(x: 0.52, y: 0.0),
                    startRadius: 2,
                    endRadius: 74
                )
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
