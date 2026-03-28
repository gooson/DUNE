import SwiftUI

/// Reveals chart content with a left-to-right mask animation.
private struct ChartDrawModifier: ViewModifier {
    @State private var drawProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .mask(alignment: .leading) {
                GeometryReader { geo in
                    Rectangle()
                        .frame(width: geo.size.width * drawProgress)
                }
            }
            .task {
                guard drawProgress == 0 else { return }
                if reduceMotion {
                    drawProgress = 1
                } else {
                    withAnimation(DS.Animation.chartDraw) {
                        drawProgress = 1
                    }
                }
            }
    }
}

extension View {
    /// Applies a left-to-right draw reveal animation to chart content.
    func chartDrawAnimation() -> some View {
        modifier(ChartDrawModifier())
    }
}
