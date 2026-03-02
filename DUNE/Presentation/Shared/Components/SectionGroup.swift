import SwiftUI

/// Groups content under a labeled section with a rounded material background.
/// Shared between Activity and Wellness tabs.
struct SectionGroup<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let iconColor: Color
    var infoAction: (() -> Void)? = nil
    var fillHeight: Bool = false
    @ViewBuilder let content: () -> Content

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var cornerRadius: CGFloat { sizeClass == .regular ? DS.Radius.lg : DS.Radius.md }
    private var outerPadding: CGFloat { sizeClass == .regular ? DS.Spacing.xl : DS.Spacing.lg }
    private var borderWidth: CGFloat { theme == .sakuraCalm ? 1.1 : 0.6 }

    private var sectionSurfaceGradient: LinearGradient {
        switch theme {
        case .sakuraCalm:
            LinearGradient(
                colors: [
                    Color("SakuraAccent").opacity(colorScheme == .dark ? 0.24 : 0.14),
                    Color("SakuraIvory").opacity(colorScheme == .dark ? 0.18 : 0.10),
                    Color("SakuraPetal").opacity(colorScheme == .dark ? 0.12 : 0.06),
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
                    Color("SakuraPetal").opacity(colorScheme == .dark ? 0.24 : 0.14),
                    Color("SakuraIvory").opacity(colorScheme == .dark ? 0.15 : 0.09),
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
                    Color("SakuraPetal").opacity(colorScheme == .dark ? 0.46 : 0.24),
                    Color("SakuraAccent").opacity(colorScheme == .dark ? 0.28 : 0.16),
                    Color("SakuraDusk").opacity(colorScheme == .dark ? 0.24 : 0.08)
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
