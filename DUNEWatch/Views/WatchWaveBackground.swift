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
    var color: Color = DS.Color.warmGlow

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let gradientTop = color.opacity(DS.Opacity.light)

        ZStack(alignment: .top) {
            WatchWaveShape(phase: phase)
                .fill(color.opacity(DS.Opacity.medium))
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
                colors: [gradientTop, .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.5)
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(DS.Animation.waveDrift) {
                phase = 2 * .pi
            }
        }
    }
}
