import SwiftUI

/// Theme selection UI with functional theme switching.
struct ThemePickerSection: View {
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @Environment(\.appTheme) private var theme

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
            HStack(spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(appTheme.swatchColors.indices, id: \.self) { index in
                        Circle()
                            .fill(appTheme.swatchColors[index])
                            .frame(width: 20, height: 20)
                    }
                }

                Text(appTheme.displayName)
                    .foregroundStyle(.primary)

                Spacer()

                if selectedTheme == appTheme {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Swatch Colors

private extension AppTheme {
    var swatchColors: [Color] {
        [accentColor, bronzeColor, duskColor]
    }
}

#Preview {
    Form {
        Section("Appearance") {
            ThemePickerSection()
        }
    }
}
