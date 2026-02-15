import SwiftUI

/// Hero card — dashboard hero, sleep score, prominent information.
struct HeroCard<Content: View>: View {
    let tintColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.xxl)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.xl)
                            .fill(tintColor.opacity(0.08).gradient)
                    )
            }
    }
}

/// Standard card — metric cards, chart containers.
struct StandardCard<Content: View>: View {
    var padding: CGFloat = DS.Spacing.lg
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content()
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(.thinMaterial)
                    .shadow(
                        color: colorScheme == .dark
                            ? .white.opacity(0.03)
                            : .black.opacity(0.06),
                        radius: 8,
                        y: 2
                    )
            }
    }
}

/// Inline card — history rows, list items.
struct InlineCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(DS.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(.ultraThinMaterial)
            }
    }
}
