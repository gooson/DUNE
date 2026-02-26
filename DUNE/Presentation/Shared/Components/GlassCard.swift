import SwiftUI

/// Hero card — dashboard hero, sleep score, prominent information.
struct HeroCard<Content: View>: View {
    let tintColor: Color
    @ViewBuilder let content: () -> Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var cornerRadius: CGFloat { sizeClass == .regular ? DS.Radius.xxl : DS.Radius.xl }
    private var cardPadding: CGFloat { sizeClass == .regular ? DS.Spacing.xxxl : DS.Spacing.xxl }

    var body: some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(cardPadding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DS.Color.warmGlow.opacity(DS.Opacity.medium),
                                        tintColor.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    // Warm accent border — top-leading highlight fades to subtle bottom-trailing
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        DS.Color.warmGlow.opacity(DS.Opacity.strong),
                                        DS.Color.warmGlow.opacity(DS.Opacity.subtle)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            }
    }
}

/// Standard card — metric cards, chart containers.
struct StandardCard<Content: View>: View {
    var padding: CGFloat?
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var cornerRadius: CGFloat { sizeClass == .regular ? DS.Radius.lg : DS.Radius.md }
    private var resolvedPadding: CGFloat {
        padding ?? (sizeClass == .regular ? DS.Spacing.xl : DS.Spacing.lg)
    }

    var body: some View {
        content()
            .padding(resolvedPadding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                DS.Color.warmGlow.opacity(
                                    colorScheme == .dark ? DS.Opacity.border : 0
                                ),
                                lineWidth: 0.5
                            )
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? DS.Color.warmGlow.opacity(DS.Opacity.light)
                            : .black.opacity(DS.Opacity.subtle),
                        radius: 10,
                        y: 2
                    )
            }
    }
}

/// Inline card — history rows, list items.
struct InlineCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var cardPadding: CGFloat { sizeClass == .regular ? DS.Spacing.lg : DS.Spacing.md }
    private var cornerRadius: CGFloat { sizeClass == .regular ? DS.Radius.md : DS.Radius.sm }

    var body: some View {
        content()
            .padding(cardPadding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            }
    }
}
