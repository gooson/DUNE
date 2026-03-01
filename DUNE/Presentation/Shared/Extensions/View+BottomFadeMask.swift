import SwiftUI

/// Shared bottom-fade mask applied to wave overlay shapes.
/// Extracted per DRY threshold (Correction #37) — used by 4 overlay views.
extension View {
    /// Applies a vertical gradient mask that fades to transparent at the bottom.
    /// - Parameter fade: Fraction of the view's height to fade (0 = no fade, 1 = full fade).
    func bottomFadeMask(_ fade: CGFloat) -> some View {
        mask {
            if fade > 0 {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 1.0 - fade),
                        .init(color: .white.opacity(0), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Rectangle()
            }
        }
    }
}
