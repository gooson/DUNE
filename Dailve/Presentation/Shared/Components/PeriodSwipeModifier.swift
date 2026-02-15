import SwiftUI

/// View modifier that adds horizontal swipe gesture for navigating between time periods.
/// Swipe left → go to previous period (offset decreases), swipe right → go to next period (offset increases).
struct PeriodSwipeModifier: ViewModifier {
    @Binding var periodOffset: Int
    let canGoForward: Bool

    @State private var dragOffset: CGFloat = 0
    private let swipeThreshold: CGFloat = 50

    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onChanged { value in
                        // Only track horizontal drags (avoid interfering with scroll)
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)
                        guard horizontal > vertical else { return }

                        withAnimation(.interactiveSpring) {
                            dragOffset = value.translation.width * 0.3
                        }
                    }
                    .onEnded { value in
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)

                        withAnimation(DS.Animation.emphasize) {
                            dragOffset = 0
                        }

                        guard horizontal > vertical else { return }

                        if value.translation.width < -swipeThreshold {
                            // Swipe left → previous period (go back in time)
                            periodOffset -= 1
                        } else if value.translation.width > swipeThreshold, canGoForward {
                            // Swipe right → next period (go forward in time)
                            periodOffset += 1
                        }
                    }
            )
            .sensoryFeedback(.selection, trigger: periodOffset)
    }
}

extension View {
    func periodSwipe(offset: Binding<Int>, canGoForward: Bool) -> some View {
        modifier(PeriodSwipeModifier(periodOffset: offset, canGoForward: canGoForward))
    }
}
