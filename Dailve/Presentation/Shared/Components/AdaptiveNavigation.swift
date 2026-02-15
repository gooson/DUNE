import SwiftUI

/// Wraps content in a NavigationStack on iPhone (compact),
/// but relies on the parent NavigationSplitView on iPad (regular).
///
/// Uses initial sizeClass to prevent NavigationStack creation/destruction
/// during iPad multitasking transitions (Slide Over, Split View).
struct AdaptiveNavigation: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var initialIsRegular: Bool?
    let title: String

    private var isRegular: Bool {
        initialIsRegular ?? (sizeClass == .regular)
    }

    func body(content: Content) -> some View {
        Group {
            if isRegular {
                content
                    .navigationTitle(title)
            } else {
                NavigationStack {
                    content
                        .navigationTitle(title)
                }
            }
        }
        .onAppear {
            if initialIsRegular == nil {
                initialIsRegular = (sizeClass == .regular)
            }
        }
    }
}

extension View {
    func adaptiveNavigation(title: String) -> some View {
        modifier(AdaptiveNavigation(title: title))
    }
}
