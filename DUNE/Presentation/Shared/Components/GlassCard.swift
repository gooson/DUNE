import SwiftUI

// P2 perf fix — cached gradients at file scope (static stored properties
// are not allowed inside generic types like HeroCard<Content>).
private enum GlassCardGradients {
    static let heroBorder = LinearGradient(
        colors: [
            DS.Color.warmGlow.opacity(DS.Opacity.strong),
            DS.Color.warmGlow.opacity(DS.Opacity.subtle)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let darkBorder = LinearGradient(
        colors: [
            DS.Color.warmGlow.opacity(DS.Opacity.strong),
            DS.Color.desertDusk.opacity(DS.Opacity.cardBorder)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let clearBorder = LinearGradient(
        colors: [Color.clear, Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let bottomSeparator = LinearGradient(
        colors: [
            DS.Color.warmGlow.opacity(0),
            DS.Color.warmGlow.opacity(DS.Opacity.cardBorder),
            DS.Color.warmGlow.opacity(0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

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
                                        tintColor.opacity(DS.Opacity.light)
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
                                GlassCardGradients.heroBorder,
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
                                colorScheme == .dark
                                    ? GlassCardGradients.darkBorder
                                    : GlassCardGradients.clearBorder,
                                lineWidth: 1
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
            .overlay(alignment: .bottom) {
                GlassCardGradients.bottomSeparator
                    .frame(height: 0.5)
                    .padding(.horizontal, DS.Spacing.md)
            }
    }
}
