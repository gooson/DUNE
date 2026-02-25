import SwiftUI

/// Compact wave animation shown during pull-to-refresh loading.
/// Uses a dedicated sine-curve path (not WaveShape) for a small pill-shaped indicator.
struct WaveRefreshIndicator: View {
    var color: Color = .accentColor

    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Correction #83 — static animation cached
    private enum Cache {
        static let drift = Animation.linear(duration: 2).repeatForever(autoreverses: false)
    }

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let amp = size.height * 0.35

            // Primary wave
            var primary = Path()
            for x in stride(from: 0, through: size.width, by: 1) {
                let norm = x / size.width
                let angle = norm * 3 * 2 * .pi + phase
                let y = midY + amp * sin(angle)
                if x == 0 { primary.move(to: CGPoint(x: x, y: y)) }
                else { primary.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(primary, with: .color(color.opacity(0.6)), lineWidth: 2.5)

            // Secondary wave (thinner, offset phase)
            var secondary = Path()
            for x in stride(from: 0, through: size.width, by: 1) {
                let norm = x / size.width
                let angle = norm * 3.5 * 2 * .pi + phase * 1.4
                let y = midY + amp * 0.6 * sin(angle)
                if x == 0 { secondary.move(to: CGPoint(x: x, y: y)) }
                else { secondary.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(secondary, with: .color(color.opacity(0.3)), lineWidth: 1.5)
        }
        .frame(width: 80, height: 20)
        .clipShape(Capsule())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Cache.drift) {
                phase = 2 * .pi
            }
        }
    }
}

// MARK: - ViewModifier

/// Adds wave-branded pull-to-refresh to any ScrollView.
/// Replaces the system spinner with `WaveRefreshIndicator`.
struct WaveRefreshModifier: ViewModifier {
    let color: Color
    let action: @Sendable () async -> Void

    /// Minimum display time so the indicator doesn't flash too briefly.
    private static let minimumDisplaySeconds: UInt64 = 1_200_000_000 // 1.2s

    @State private var showIndicator = false

    func body(content: Content) -> some View {
        content
            .refreshable {
                showIndicator = true
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { try? await Task.sleep(nanoseconds: Self.minimumDisplaySeconds) }
                    group.addTask { await action() }
                    await group.waitForAll()
                }
                showIndicator = false
            }
            .overlay(alignment: .top) {
                if showIndicator {
                    WaveRefreshIndicator(color: color)
                        .padding(.top, DS.Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(DS.Animation.snappy, value: showIndicator)
                }
            }
    }
}

extension View {
    /// Wave-branded pull-to-refresh.
    func waveRefreshable(
        color: Color = .accentColor,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        modifier(WaveRefreshModifier(
            color: color,
            action: action
        ))
    }
}
