import SwiftUI

// P2 perf fix — cached gradients at file scope (static stored properties
// are not allowed inside generic types like HeroCard<Content>).
private enum GlassCardGradients {
    // Desert Warm
    private static let desertHeroBorder = LinearGradient(
        colors: [
            DS.Color.warmGlow.opacity(DS.Opacity.strong),
            DS.Color.warmGlow.opacity(DS.Opacity.subtle)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let desertDarkBorder = LinearGradient(
        colors: [
            DS.Color.warmGlow.opacity(DS.Opacity.strong),
            DS.Color.desertDusk.opacity(DS.Opacity.cardBorder)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let desertBottomSeparator = LinearGradient(
        colors: [
            DS.Color.warmGlow.opacity(0),
            DS.Color.warmGlow.opacity(DS.Opacity.cardBorder),
            DS.Color.warmGlow.opacity(0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Ocean Cool
    private static let oceanAccent = Color("OceanAccent")
    private static let oceanDusk = Color("OceanDusk")
    private static let oceanHeroBorder = LinearGradient(
        colors: [
            oceanAccent.opacity(DS.Opacity.strong),
            oceanAccent.opacity(DS.Opacity.subtle)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let oceanDarkBorder = LinearGradient(
        colors: [
            oceanAccent.opacity(DS.Opacity.strong),
            oceanDusk.opacity(DS.Opacity.cardBorder)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let oceanBottomSeparator = LinearGradient(
        colors: [
            oceanAccent.opacity(0),
            oceanAccent.opacity(DS.Opacity.cardBorder),
            oceanAccent.opacity(0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Forest Green
    private static let forestAccent = Color("ForestAccent")
    private static let forestDusk = Color("ForestDusk")
    private static let forestHeroBorder = LinearGradient(
        colors: [
            forestAccent.opacity(DS.Opacity.strong),
            forestAccent.opacity(DS.Opacity.subtle)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let forestDarkBorder = LinearGradient(
        colors: [
            forestAccent.opacity(DS.Opacity.strong),
            forestDusk.opacity(DS.Opacity.cardBorder)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let forestBottomSeparator = LinearGradient(
        colors: [
            forestAccent.opacity(0),
            forestAccent.opacity(DS.Opacity.cardBorder),
            forestAccent.opacity(0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let clearBorder = LinearGradient(
        colors: [Color.clear, Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func heroBorder(for theme: AppTheme) -> LinearGradient {
        switch theme {
        case .desertWarm:  desertHeroBorder
        case .oceanCool:   oceanHeroBorder
        case .forestGreen: forestHeroBorder
        }
    }
    static func darkBorder(for theme: AppTheme) -> LinearGradient {
        switch theme {
        case .desertWarm:  desertDarkBorder
        case .oceanCool:   oceanDarkBorder
        case .forestGreen: forestDarkBorder
        }
    }
    static func bottomSeparator(for theme: AppTheme) -> LinearGradient {
        switch theme {
        case .desertWarm:  desertBottomSeparator
        case .oceanCool:   oceanBottomSeparator
        case .forestGreen: forestBottomSeparator
        }
    }
}

/// Hero card — dashboard hero, sleep score, prominent information.
struct HeroCard<Content: View>: View {
    let tintColor: Color
    @ViewBuilder let content: () -> Content

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme

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
                                        theme.accentColor.opacity(DS.Opacity.medium),
                                        tintColor.opacity(DS.Opacity.light)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    // Accent border — top-leading highlight fades to subtle bottom-trailing
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                GlassCardGradients.heroBorder(for: theme),
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
    @Environment(\.appTheme) private var theme

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
                                    ? GlassCardGradients.darkBorder(for: theme)
                                    : GlassCardGradients.clearBorder,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? theme.accentColor.opacity(DS.Opacity.light)
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
    @Environment(\.appTheme) private var theme

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
                GlassCardGradients.bottomSeparator(for: theme)
                    .frame(height: 0.5)
                    .padding(.horizontal, DS.Spacing.md)
            }
    }
}
