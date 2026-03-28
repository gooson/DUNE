import SwiftUI

/// Animates content entrance with slide-up, fade-in, and subtle scale.
/// Supports staggered delay based on index for sequential card appearance.
/// Items sharing the same index animate simultaneously (delay group semantics).
private struct StaggeredAppearModifier: ViewModifier {
    let index: Int

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
                        DS.Animation.staggerDelay(index: index)
                    ),
                value: hasAppeared
            )
            .task {
                guard !hasAppeared else { return }
                hasAppeared = true
            }
    }
}

extension View {
    /// Applies a staggered entrance animation (slide-up + fade + scale).
    /// - Parameter index: Position in the stagger sequence (0-based).
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppearModifier(index: index))
    }
}
