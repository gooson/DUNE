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

    // Sakura Calm
    private static let sakuraAccent = Color("SakuraAccent")
    private static let sakuraDusk = Color("SakuraDusk")
    private static let sakuraHeroBorder = LinearGradient(
        colors: [
            sakuraAccent.opacity(DS.Opacity.strong),
            sakuraAccent.opacity(DS.Opacity.subtle)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let sakuraDarkBorder = LinearGradient(
        colors: [
            sakuraAccent.opacity(DS.Opacity.strong),
            sakuraDusk.opacity(DS.Opacity.cardBorder)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let sakuraBottomSeparator = LinearGradient(
        colors: [
            sakuraAccent.opacity(0),
            sakuraAccent.opacity(DS.Opacity.cardBorder),
            sakuraAccent.opacity(0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Arctic Dawn
    private static let arcticAccent = Color("ArcticAccent")
    private static let arcticAurora = Color("ArcticAurora")
    private static let arcticDusk = Color("ArcticDusk")
    private static let arcticFrost = Color("ArcticFrost")
    private static let arcticHeroBorder = LinearGradient(
        colors: [
            arcticFrost.opacity(DS.Opacity.strong),
            arcticAccent.opacity(DS.Opacity.subtle)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let arcticDarkBorder = LinearGradient(
        colors: [
            arcticFrost.opacity(DS.Opacity.strong),
            arcticDusk.opacity(DS.Opacity.cardBorder)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let arcticBottomSeparator = LinearGradient(
        colors: [
            arcticFrost.opacity(0),
            arcticFrost.opacity(DS.Opacity.cardBorder),
            arcticFrost.opacity(0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Solar Pop
    private static let solarAccent = Color("SolarAccent")
    private static let solarDusk = Color("SolarDusk")
    private static let solarCore = Color("SolarCore")
    private static let solarGlow = Color("SolarGlow")
    private static let solarEmber = Color("SolarEmber")

    // Hanok
    private static let hanokAccent = Color("HanokAccent")
    private static let hanokDusk = Color("HanokDusk")
    private static let hanokMid = Color("HanokMid")
    private static let hanokMist = Color("HanokMist")
    private static let hanokHeroBorder = LinearGradient(
        colors: [
            hanokAccent.opacity(DS.Opacity.strong),
            hanokAccent.opacity(DS.Opacity.subtle)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let hanokDarkBorder = LinearGradient(
        colors: [
            hanokAccent.opacity(DS.Opacity.strong),
            hanokDusk.opacity(DS.Opacity.cardBorder)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let hanokBottomSeparator = LinearGradient(
        colors: [
            hanokAccent.opacity(0),
            hanokAccent.opacity(DS.Opacity.cardBorder),
            hanokAccent.opacity(0)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    private static let solarHeroBorder = LinearGradient(
        colors: [
            solarGlow.opacity(DS.Opacity.strong),
            solarAccent.opacity(DS.Opacity.subtle)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let solarDarkBorder = LinearGradient(
        colors: [
            solarGlow.opacity(DS.Opacity.strong),
            solarDusk.opacity(DS.Opacity.cardBorder)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private static let solarBottomSeparator = LinearGradient(
        colors: [
            solarGlow.opacity(0),
            solarGlow.opacity(DS.Opacity.cardBorder),
            solarGlow.opacity(0)
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
        case .sakuraCalm:  sakuraHeroBorder
        case .arcticDawn:  arcticHeroBorder
        case .solarPop:    solarHeroBorder
        case .hanok:       hanokHeroBorder
        }
    }
    static func darkBorder(for theme: AppTheme) -> LinearGradient {
        switch theme {
        case .desertWarm:  desertDarkBorder
        case .oceanCool:   oceanDarkBorder
        case .forestGreen: forestDarkBorder
        case .sakuraCalm:  sakuraDarkBorder
        case .arcticDawn:  arcticDarkBorder
        case .solarPop:    solarDarkBorder
        case .hanok:       hanokDarkBorder
        }
    }
    static func bottomSeparator(for theme: AppTheme) -> LinearGradient {
        switch theme {
        case .desertWarm:  desertBottomSeparator
        case .oceanCool:   oceanBottomSeparator
        case .forestGreen: forestBottomSeparator
        case .sakuraCalm:  sakuraBottomSeparator
        case .arcticDawn:  arcticBottomSeparator
        case .solarPop:    solarBottomSeparator
        case .hanok:       hanokBottomSeparator
        }
    }

    static func heroSurface(for theme: AppTheme, colorScheme: ColorScheme) -> LinearGradient {
        switch theme {
        case .sakuraCalm:
            LinearGradient(
                colors: [
                    sakuraAccent.opacity(colorScheme == .dark ? 0.22 : 0.28),
                    Color("SakuraIvory").opacity(colorScheme == .dark ? 0.12 : 0.16),
                    Color("SakuraPetal").opacity(colorScheme == .dark ? 0.10 : 0.12),
                    sakuraDusk.opacity(colorScheme == .dark ? 0.10 : 0.00),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .arcticDawn:
            LinearGradient(
                colors: [
                    arcticAurora.opacity(colorScheme == .dark ? 0.20 : 0.24),
                    arcticFrost.opacity(colorScheme == .dark ? 0.16 : 0.20),
                    arcticDusk.opacity(colorScheme == .dark ? 0.10 : 0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solarPop:
            LinearGradient(
                colors: [
                    solarGlow.opacity(colorScheme == .dark ? 0.22 : 0.24),
                    solarCore.opacity(colorScheme == .dark ? 0.16 : 0.18),
                    solarEmber.opacity(colorScheme == .dark ? 0.10 : 0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hanok:
            LinearGradient(
                colors: [
                    hanokAccent.opacity(colorScheme == .dark ? 0.20 : 0.24),
                    hanokMid.opacity(colorScheme == .dark ? 0.14 : 0.16),
                    hanokDusk.opacity(colorScheme == .dark ? 0.10 : 0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .desertWarm, .oceanCool, .forestGreen:
            clearBorder
        }
    }

    static func standardSurface(for theme: AppTheme, colorScheme: ColorScheme) -> LinearGradient {
        switch theme {
        case .sakuraCalm:
            LinearGradient(
                colors: [
                    Color("SakuraIvory").opacity(colorScheme == .dark ? 0.14 : 0.16),
                    sakuraAccent.opacity(colorScheme == .dark ? 0.12 : 0.14),
                    Color("SakuraPetal").opacity(colorScheme == .dark ? 0.08 : 0.10),
                    sakuraDusk.opacity(colorScheme == .dark ? 0.10 : 0.00),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .arcticDawn:
            LinearGradient(
                colors: [
                    arcticFrost.opacity(colorScheme == .dark ? 0.18 : 0.16),
                    arcticAurora.opacity(colorScheme == .dark ? 0.14 : 0.12),
                    arcticDusk.opacity(colorScheme == .dark ? 0.10 : 0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solarPop:
            LinearGradient(
                colors: [
                    solarGlow.opacity(colorScheme == .dark ? 0.18 : 0.16),
                    solarCore.opacity(colorScheme == .dark ? 0.14 : 0.12),
                    solarDusk.opacity(colorScheme == .dark ? 0.10 : 0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hanok:
            LinearGradient(
                colors: [
                    hanokAccent.opacity(colorScheme == .dark ? 0.16 : 0.14),
                    hanokMid.opacity(colorScheme == .dark ? 0.12 : 0.10),
                    hanokDusk.opacity(colorScheme == .dark ? 0.10 : 0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .desertWarm, .oceanCool, .forestGreen:
            clearBorder
        }
    }

    static func inlineSurface(for theme: AppTheme, colorScheme: ColorScheme) -> LinearGradient {
        switch theme {
        case .sakuraCalm:
            LinearGradient(
                colors: [
                    Color("SakuraIvory").opacity(colorScheme == .dark ? 0.12 : 0.13),
                    sakuraAccent.opacity(colorScheme == .dark ? 0.08 : 0.10),
                    sakuraDusk.opacity(colorScheme == .dark ? 0.08 : 0.00),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .arcticDawn:
            LinearGradient(
                colors: [
                    arcticFrost.opacity(colorScheme == .dark ? 0.13 : 0.12),
                    arcticAurora.opacity(colorScheme == .dark ? 0.10 : 0.08),
                    arcticDusk.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solarPop:
            LinearGradient(
                colors: [
                    solarGlow.opacity(colorScheme == .dark ? 0.14 : 0.12),
                    solarCore.opacity(colorScheme == .dark ? 0.10 : 0.08),
                    solarDusk.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hanok:
            LinearGradient(
                colors: [
                    hanokAccent.opacity(colorScheme == .dark ? 0.12 : 0.11),
                    hanokMid.opacity(colorScheme == .dark ? 0.08 : 0.07),
                    hanokDusk.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .desertWarm, .oceanCool, .forestGreen:
            clearBorder
        }
    }

    static func topBloom(for theme: AppTheme, colorScheme: ColorScheme) -> LinearGradient {
        switch theme {
        case .sakuraCalm:
            LinearGradient(
                colors: [
                    Color("SakuraPetal").opacity(colorScheme == .dark ? 0.18 : 0.20),
                    Color("SakuraIvory").opacity(colorScheme == .dark ? 0.10 : 0.12),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .arcticDawn:
            LinearGradient(
                colors: [
                    arcticFrost.opacity(colorScheme == .dark ? 0.20 : 0.18),
                    arcticAurora.opacity(colorScheme == .dark ? 0.10 : 0.09),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .solarPop:
            LinearGradient(
                colors: [
                    solarGlow.opacity(colorScheme == .dark ? 0.20 : 0.18),
                    solarCore.opacity(colorScheme == .dark ? 0.10 : 0.09),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .hanok:
            LinearGradient(
                colors: [
                    hanokMist.opacity(colorScheme == .dark ? 0.18 : 0.16),
                    hanokAccent.opacity(colorScheme == .dark ? 0.10 : 0.09),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .desertWarm, .oceanCool, .forestGreen:
            clearBorder
        }
    }

    static func cardBorder(for theme: AppTheme, colorScheme: ColorScheme) -> LinearGradient {
        switch theme {
        case .sakuraCalm:
            LinearGradient(
                colors: [
                    Color("SakuraPetal").opacity(colorScheme == .dark ? 0.36 : 0.30),
                    sakuraAccent.opacity(colorScheme == .dark ? 0.24 : 0.21),
                    sakuraDusk.opacity(colorScheme == .dark ? 0.18 : 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .arcticDawn:
            LinearGradient(
                colors: [
                    arcticFrost.opacity(colorScheme == .dark ? 0.36 : 0.30),
                    arcticAccent.opacity(colorScheme == .dark ? 0.24 : 0.21),
                    arcticDusk.opacity(colorScheme == .dark ? 0.16 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solarPop:
            LinearGradient(
                colors: [
                    solarGlow.opacity(colorScheme == .dark ? 0.36 : 0.30),
                    solarAccent.opacity(colorScheme == .dark ? 0.24 : 0.21),
                    solarDusk.opacity(colorScheme == .dark ? 0.16 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hanok:
            LinearGradient(
                colors: [
                    hanokMist.opacity(colorScheme == .dark ? 0.32 : 0.26),
                    hanokAccent.opacity(colorScheme == .dark ? 0.22 : 0.18),
                    hanokDusk.opacity(colorScheme == .dark ? 0.16 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .desertWarm, .oceanCool, .forestGreen:
            clearBorder
        }
    }
}

/// Hero card — dashboard hero, sleep score, prominent information.
struct HeroCard<Content: View>: View {
    let tintColor: Color
    @ViewBuilder let content: () -> Content

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

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
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(GlassCardGradients.heroSurface(for: theme, colorScheme: colorScheme))
                    )
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(GlassCardGradients.topBloom(for: theme, colorScheme: colorScheme))
                            .frame(height: sizeClass == .regular ? 72 : 58)
                    }
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
                            .fill(GlassCardGradients.standardSurface(for: theme, colorScheme: colorScheme))
                    )
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(GlassCardGradients.topBloom(for: theme, colorScheme: colorScheme))
                            .frame(height: sizeClass == .regular ? 52 : 42)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                theme.usesGlassBorder
                                    ? GlassCardGradients.cardBorder(for: theme, colorScheme: colorScheme)
                                    : (colorScheme == .dark
                                        ? GlassCardGradients.darkBorder(for: theme)
                                        : GlassCardGradients.clearBorder),
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
    @Environment(\.colorScheme) private var colorScheme

    private var cardPadding: CGFloat { sizeClass == .regular ? DS.Spacing.lg : DS.Spacing.md }
    private var cornerRadius: CGFloat { sizeClass == .regular ? DS.Radius.md : DS.Radius.sm }

    var body: some View {
        content()
            .padding(cardPadding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(GlassCardGradients.inlineSurface(for: theme, colorScheme: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                theme.usesGlassBorder
                                    ? GlassCardGradients.cardBorder(for: theme, colorScheme: colorScheme)
                                    : GlassCardGradients.clearBorder,
                                lineWidth: theme.usesGlassBorder ? 0.9 : 0
                            )
                    )
            }
            .overlay(alignment: .bottom) {
                GlassCardGradients.bottomSeparator(for: theme)
                    .frame(height: 0.5)
                    .padding(.horizontal, DS.Spacing.md)
            }
    }
}
