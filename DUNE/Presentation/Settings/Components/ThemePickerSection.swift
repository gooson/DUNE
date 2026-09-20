import SwiftUI

/// Theme selection UI with functional theme switching.
struct ThemePickerSection: View {
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(AppTheme.allCases, id: \.self) { appTheme in
                themeRow(appTheme)
            }
        }
    }

    private func themeRow(_ appTheme: AppTheme) -> some View {
        Button {
            selectedTheme = appTheme
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.md) {
                    Text(appTheme.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: DS.Spacing.sm)

                    if selectedTheme == appTheme {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(appTheme.accentColor)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                }

                ThemeCardPreview(theme: appTheme)
                    .accessibilityHidden(true)
            }
            .padding(DS.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appTheme.displayName)
        .accessibilityAddTraits(selectedTheme == appTheme ? .isSelected : [])
        .accessibilityIdentifier("settings-theme-\(appTheme.rawValue)")
    }
}

/// Uses the production card and background, with sample data and all motion disabled.
private struct ThemeCardPreview: View {
    let theme: AppTheme

    var body: some View {
        StandardCard(padding: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    ProgressRingView(
                        progress: 0.84,
                        ringColor: theme.scoreGood,
                        lineWidth: 4,
                        size: 44
                    )
                    Text(verbatim: "84")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Condition")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Sample preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background { TabWaveBackground() }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .environment(\.appTheme, theme)
        .environment(\.wavePreset, .today)
        .environment(\.weatherAtmosphere, .default)
        .environment(\.accessibilityReduceMotion, true)
        .environment(\.scenePhase, .inactive)
        // Decorative samples retain their composition; the actual selector title scales freely.
        .dynamicTypeSize(.medium)
    }
}

#Preview {
    Form {
        Section("Appearance") {
            ThemePickerSection()
        }
    }
}
