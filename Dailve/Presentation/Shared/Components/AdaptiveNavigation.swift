import SwiftUI

/// Wraps content in a NavigationStack on iPhone (compact),
/// but relies on the parent NavigationSplitView on iPad (regular).
struct AdaptiveNavigation: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let title: String

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
                .navigationTitle(title)
        } else {
            NavigationStack {
                content
                    .navigationTitle(title)
            }
        }
    }
}

extension View {
    func adaptiveNavigation(title: String) -> some View {
        modifier(AdaptiveNavigation(title: title))
    }
}
