import SwiftUI

/// Animates content entrance with slide-up, fade-in, and subtle scale.
/// Supports staggered delay based on index for sequential card appearance.
private struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    let maxIndex: Int

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 12)
            .scaleEffect(hasAppeared ? 1 : 0.97, anchor: .top)
            .animation(
                reduceMotion
                    ? .none
                    : DS.Animation.cardEntrance.delay(
                        DS.Animation.staggerDelay(index: index, base: baseDelay, max: maxIndex)
                    ),
                value: hasAppeared
            )
            .onAppear {
                guard !hasAppeared else { return }
                if reduceMotion {
                    hasAppeared = true
                } else {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    /// Applies a staggered entrance animation (slide-up + fade + scale).
    /// - Parameters:
    ///   - index: Position in the stagger sequence (0-based).
    ///   - baseDelay: Delay per item in seconds (default 0.06s).
    ///   - maxIndex: Maximum index for delay calculation (default 8).
    func staggeredAppear(index: Int, baseDelay: Double = 0.06, maxIndex: Int = 8) -> some View {
        modifier(StaggeredAppearModifier(index: index, baseDelay: baseDelay, maxIndex: maxIndex))
    }
}
