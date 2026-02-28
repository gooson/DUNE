import SwiftUI
import UIKit

/// Compact wave animation shown during pull-to-refresh loading.
/// Uses a dedicated sine-curve path (not WaveShape) for a small pill-shaped indicator.
struct WaveRefreshIndicator: View {
    var color: Color = DS.Color.warmGlow

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
    let colorOverride: Color?
    let action: @Sendable () async -> Void

    @Environment(\.waveColor) private var waveColor

    /// Minimum display time for satisfying animation visibility.
    private static let minimumDisplayNanoseconds: UInt64 = 1_800_000_000 // 1.8s

    @State private var showIndicator = false

    private var resolvedColor: Color { colorOverride ?? waveColor }

    func body(content: Content) -> some View {
        content
            .refreshable {
                showIndicator = true
                // Always reset indicator on ALL exit paths — including Task cancellation.
                // Without defer, cancellation during settle delay leaves showIndicator stuck true.
                defer { showIndicator = false }
                await withTaskGroup(of: Void.self) { group in
                    // Correction #141 — propagate CancellationError so the group
                    // drains properly; try? would break the minimum-display floor.
                    group.addTask {
                        do { try await Task.sleep(nanoseconds: Self.minimumDisplayNanoseconds) }
                        catch is CancellationError { /* let group finish naturally */ }
                        catch {}
                    }
                    group.addTask { await action() }
                    await group.waitForAll()
                }
                // Brief settle delay so UIRefreshControl finishes scroll restoration
                // before we remove our overlay. Skipped on cancellation (defer still resets).
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
            // Hide only this scroll view's system spinner to avoid overlap.
            .background {
                RefreshControlTintHider()
                    .frame(width: 0, height: 0)
            }
            .overlay(alignment: .top) {
                if showIndicator {
                    WaveRefreshIndicator(color: resolvedColor)
                        .padding(.top, DS.Spacing.sm)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.6, anchor: .top)),
                                removal: .opacity.combined(with: .scale(scale: 0.8, anchor: .top))
                            )
                        )
                        .animation(DS.Animation.snappy, value: showIndicator)
                }
            }
    }
}

/// Finds the underlying ScrollView refresh control and hides its tint.
@MainActor
private struct RefreshControlTintHider: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let refreshControl = findRefreshControl(from: uiView) {
            refreshControl.tintColor = .clear
        }
    }

    private func findRefreshControl(from view: UIView) -> UIRefreshControl? {
        guard let scrollView = view.enclosingScrollView else { return nil }
        if let refreshControl = scrollView.refreshControl {
            return refreshControl
        }
        return scrollView.subviews.first(where: { $0 is UIRefreshControl }) as? UIRefreshControl
    }
}

@MainActor
private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var current = superview
        while let view = current {
            if let scrollView = view as? UIScrollView {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }
}

extension View {
    /// Wave-branded pull-to-refresh.
    /// Color defaults to the tab's `\.waveColor` environment value for automatic consistency.
    /// Pass an explicit `color` only when an override is needed.
    func waveRefreshable(
        color: Color? = nil,
        action: @escaping @Sendable () async -> Void
    ) -> some View {
        modifier(WaveRefreshModifier(
            colorOverride: color,
            action: action
        ))
    }
}
