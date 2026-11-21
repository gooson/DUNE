import SwiftUI
import UIKit

/// Selecting a poster opens a preview without changing the stored theme.
struct ThemeGalleryView: View {
    let onPreview: (AppTheme) -> Void

    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private func columns(for width: CGFloat) -> [GridItem] {
        let count = width < 270 ? 1 : (width < 340 || dynamicTypeSize >= .xxxLarge ? 2 : 3)
        return Array(repeating: GridItem(.flexible(minimum: 0), spacing: DS.Spacing.sm), count: count)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns(for: proxy.size.width), alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button { onPreview(theme) } label: {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                ThemePoster(theme: theme)
                                    .aspectRatio(1.05, contentMode: .fit)
                                    .overlay(alignment: .bottomTrailing) {
                                        if selectedTheme == theme {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, theme.accentColor)
                                                .padding(DS.Spacing.sm)
                                        }
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: DS.Radius.md)
                                            .strokeBorder(selectedTheme == theme ? theme.accentColor : .clear, lineWidth: 3)
                                    }
                                Text(theme.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(theme.displayName)
                        .accessibilityHint("Preview theme")
                        .accessibilityAddTraits(selectedTheme == theme ? .isSelected : [])
                        .accessibilityIdentifier("settings-theme-\(theme.rawValue)")
                    }
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: 660)
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("settings-theme-gallery")
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// The hub card reflects the saved theme after Apply.
struct SettingsCurrentThemeCard: View {
    let onOpen: () -> Void

    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 0) {
                ThemePoster(theme: selectedTheme, cornerRadius: 0)
                    .frame(height: 118)
                Group {
                    if dynamicTypeSize >= .xxxLarge {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            themeTitle
                            changeAction
                        }
                    } else {
                        HStack(alignment: .center, spacing: DS.Spacing.sm) {
                            themeTitle
                            Spacer(minLength: 0)
                            changeAction
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Change theme, current \(selectedTheme.displayName)"))
        .accessibilityHint("Open theme gallery")
        .accessibilityIdentifier("settings-section-appearance")
    }

    private var themeTitle: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Current theme")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(selectedTheme.displayName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var changeAction: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text("Change theme")
            Image(systemName: "chevron.right")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(selectedTheme.accentColor)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(selectedTheme.accentColor.opacity(0.1), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// The selected candidate and appearance are local until Apply is pressed.
struct SettingsThemePreview: View {
    let theme: AppTheme
    let onApply: () -> Void

    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var previewColorScheme: ColorScheme?

    private var colorScheme: ColorScheme { previewColorScheme ?? systemColorScheme }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(theme.displayName)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: DS.Spacing.xs) {
                        appearanceButton("Light appearance", symbol: "sun.max", scheme: .light, identifier: "settings-preview-light")
                        appearanceButton("Dark appearance", symbol: "moon", scheme: .dark, identifier: "settings-preview-dark")
                    }
                    .padding(DS.Spacing.xs)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Today preview appearance")

                    ThemeTodaySample(theme: theme)
                        .environment(\.colorScheme, colorScheme)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Today preview with sample data")
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button {
                selectedTheme = theme
                onApply()
            } label: {
                Group {
                    if selectedTheme == theme {
                        Text("Current theme")
                    } else {
                        Text("Apply this theme")
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(theme.prominentButtonForegroundColor(for: systemColorScheme))
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accentColor)
            .disabled(selectedTheme == theme)
            .accessibilityIdentifier("settings-theme-apply")
            .padding(DS.Spacing.lg)
            .background(.regularMaterial)
        }
    }

    private func appearanceButton(
        _ title: LocalizedStringKey,
        symbol: String,
        scheme: ColorScheme,
        identifier: String
    ) -> some View {
        let isSelected = colorScheme == scheme
        return Button {
            previewColorScheme = scheme
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 40)
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }
}

private struct ThemePoster: View {
    let theme: AppTheme
    var cornerRadius: CGFloat = DS.Radius.md

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                theme.accentColor
                if let poster = ArtistThemeEdition.forTheme(theme)?.poster {
                    Image(uiImage: poster)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .accessibilityHidden(true)
    }
}

/// Native Today components with fixed example values and no HealthKit reads.
private struct ThemeTodaySample: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 0) {
            ThemePoster(theme: theme, cornerRadius: 0)
                .frame(height: 160)
                .overlay(alignment: .bottomLeading) {
                    Text("Today")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.55), radius: 4)
                        .padding(DS.Spacing.lg)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("Sample data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                StandardCard(padding: DS.Spacing.lg) {
                    HStack(spacing: DS.Spacing.lg) {
                        ZStack {
                            ProgressRingView(progress: 0.84, ringColor: theme.scoreGood, lineWidth: 7, size: 84)
                            Text(verbatim: "84")
                                .font(.title2.weight(.bold).monospacedDigit())
                        }
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Condition").font(.headline)
                            Text("Good").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background { TabWaveBackground() }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .environment(\.appTheme, theme)
        .environment(\.wavePreset, .today)
        .environment(\.weatherAtmosphere, .default)
        .environment(\.waveAnimationEnabled, false)
        .environment(\.scenePhase, .inactive)
        .transaction {
            $0.animation = nil
            $0.disablesAnimations = true
        }
    }
}
