import SwiftUI

/// Groups content under a labeled section with a rounded material background.
/// Shared between Activity and Wellness tabs.
struct SectionGroup<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let iconColor: Color
    var subtitle: LocalizedStringKey? = nil
    var infoAction: (() -> Void)? = nil
    var fillHeight: Bool = false
    @ViewBuilder let content: () -> Content

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var cornerRadius: CGFloat { sizeClass == .regular ? DS.Radius.lg : DS.Radius.md }
    private var outerPadding: CGFloat { sizeClass == .regular ? DS.Spacing.xl : DS.Spacing.lg }
    private var borderWidth: CGFloat {
        switch theme {
        case .sakuraCalm: 0.95
        case .arcticDawn: 0.85
        case .solarPop:   0.9
        case .desertWarm, .oceanCool, .forestGreen: 0.6
        }
    }

    private var sectionSurfaceGradient: LinearGradient {
        switch theme {
        case .sakuraCalm:
            LinearGradient(
                colors: [
                    Color("SakuraAccent").opacity(colorScheme == .dark ? 0.14 : 0.14),
                    Color("SakuraIvory").opacity(colorScheme == .dark ? 0.12 : 0.10),
                    Color("SakuraPetal").opacity(colorScheme == .dark ? 0.08 : 0.06),
                    Color("SakuraDusk").opacity(colorScheme == .dark ? 0.10 : 0.00),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .arcticDawn:
            LinearGradient(
                colors: [
                    Color("ArcticAurora").opacity(colorScheme == .dark ? 0.18 : 0.16),
                    Color("ArcticFrost").opacity(colorScheme == .dark ? 0.14 : 0.12),
                    Color("ArcticDeep").opacity(colorScheme == .dark ? 0.11 : 0.06),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solarPop:
            LinearGradient(
                colors: [
                    Color("SolarGlow").opacity(colorScheme == .dark ? 0.18 : 0.16),
                    Color("SolarCore").opacity(colorScheme == .dark ? 0.15 : 0.12),
                    Color("SolarEmber").opacity(colorScheme == .dark ? 0.11 : 0.06),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .desertWarm, .oceanCool, .forestGreen:
            theme.cardBackgroundGradient
        }
    }

    private var sectionTopBloom: LinearGradient {
        switch theme {
        case .sakuraCalm:
            LinearGradient(
                colors: [
                    Color("SakuraPetal").opacity(colorScheme == .dark ? 0.15 : 0.14),
                    Color("SakuraIvory").opacity(colorScheme == .dark ? 0.08 : 0.09),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .arcticDawn:
            LinearGradient(
                colors: [
                    Color("ArcticFrost").opacity(colorScheme == .dark ? 0.18 : 0.14),
                    Color("ArcticAurora").opacity(colorScheme == .dark ? 0.10 : 0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .solarPop:
            LinearGradient(
                colors: [
                    Color("SolarGlow").opacity(colorScheme == .dark ? 0.20 : 0.16),
                    Color("SolarCore").opacity(colorScheme == .dark ? 0.10 : 0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .desertWarm, .oceanCool, .forestGreen:
            LinearGradient(
                colors: [theme.accentColor.opacity(0.08), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var sectionBorderGradient: LinearGradient {
        switch theme {
        case .sakuraCalm:
            LinearGradient(
                colors: [
                    Color("SakuraPetal").opacity(colorScheme == .dark ? 0.34 : 0.24),
                    Color("SakuraAccent").opacity(colorScheme == .dark ? 0.20 : 0.16),
                    Color("SakuraDusk").opacity(colorScheme == .dark ? 0.16 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .arcticDawn:
            LinearGradient(
                colors: [
                    Color("ArcticFrost").opacity(colorScheme == .dark ? 0.34 : 0.26),
                    Color("ArcticAccent").opacity(colorScheme == .dark ? 0.22 : 0.16),
                    Color("ArcticDusk").opacity(colorScheme == .dark ? 0.16 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .solarPop:
            LinearGradient(
                colors: [
                    Color("SolarGlow").opacity(colorScheme == .dark ? 0.34 : 0.28),
                    Color("SolarAccent").opacity(colorScheme == .dark ? 0.24 : 0.18),
                    Color("SolarDusk").opacity(colorScheme == .dark ? 0.16 : 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .desertWarm, .oceanCool, .forestGreen:
            LinearGradient(
                colors: [
                    theme.accentColor.opacity(colorScheme == .dark ? 0.26 : 0.12),
                    theme.duskColor.opacity(colorScheme == .dark ? 0.18 : 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.xs) {
                    // Theme accent bar
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.sectionAccentGradient)
                        .frame(width: 2, height: 14)

                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(iconColor)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Color.textSecondary)

                    if let infoAction {
                        Spacer()

                        Button(action: infoAction) {
                            Image(systemName: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(DS.Color.textSecondary)
                        }
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textTertiary)
                        .padding(.leading, DS.Spacing.xs)
                }
            }
            .padding(.horizontal, DS.Spacing.xs)

            // Card content
            content()
        }
        .padding(outerPadding)
        .frame(maxHeight: fillHeight ? .infinity : nil, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(sectionSurfaceGradient)
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(sectionTopBloom)
                        .frame(height: sizeClass == .regular ? 56 : 42)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(sectionBorderGradient, lineWidth: borderWidth)
                )
        }
    }
}
