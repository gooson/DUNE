import SwiftUI

/// A button style that provides press-down scale feedback with haptic.
struct PressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(
                configuration.isPressed ? DS.Animation.pressDown : DS.Animation.pressUp,
                value: configuration.isPressed
            )
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

extension View {
    /// Wraps content in a Button with press-scale + haptic feedback.
    /// - Parameter action: The action to perform on tap.
    func pressableCard(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            self
        }
        .buttonStyle(PressableCardStyle())
    }
}
