import SwiftUI

/// View modifier that adds horizontal swipe gesture for navigating between time periods.
/// Uses `.simultaneousGesture` to coexist with ScrollView's vertical scroll.
/// Swipe left → go to previous period (offset decreases), swipe right → go to next period (offset increases).
struct PeriodSwipeModifier: ViewModifier {
    @Binding var periodOffset: Int
    let canGoForward: Bool

    @State private var isHorizontalDrag = false
    @State private var dragOffset: CGFloat = 0
    private let swipeThreshold: CGFloat = 60

    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)

                        // Lock direction on first significant movement
                        if !isHorizontalDrag && horizontal > 15 && horizontal > vertical * 1.8 {
                            isHorizontalDrag = true
                        }

                        guard isHorizontalDrag else { return }

                        withAnimation(.interactiveSpring) {
                            dragOffset = value.translation.width * 0.25
                        }
                    }
                    .onEnded { value in
                        let wasHorizontal = isHorizontalDrag
                        isHorizontalDrag = false

                        withAnimation(DS.Animation.emphasize) {
                            dragOffset = 0
                        }

                        guard wasHorizontal else { return }

                        if value.translation.width < -swipeThreshold {
                            periodOffset -= 1
                        } else if value.translation.width > swipeThreshold, canGoForward {
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
