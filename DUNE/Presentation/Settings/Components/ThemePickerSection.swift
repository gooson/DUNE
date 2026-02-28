import SwiftUI

/// Theme selection UI with functional theme switching.
struct ThemePickerSection: View {
    @AppStorage("com.dune.app.theme") private var selectedTheme: AppTheme = .desertWarm
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(AppTheme.allCases, id: \.self) { appTheme in
                themeRow(appTheme)
            }

            themeRow(
                name: "Forest Green",
                colors: [.green, .mint, .teal],
                isSelected: false,
                isAvailable: false
            )
        }
    }

    private func themeRow(_ appTheme: AppTheme) -> some View {
        Button {
            withAnimation(DS.Animation.standard) {
                selectedTheme = appTheme
            }
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

    /// Placeholder for future themes (Forest Green etc.)
    private func themeRow(
        name: String,
        colors: [Color],
        isSelected: Bool,
        isAvailable: Bool
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(colors.indices, id: \.self) { index in
                    Circle()
                        .fill(colors[index])
                        .frame(width: 20, height: 20)
                }
            }

            Text(name)
                .foregroundStyle(.secondary)

            Spacer()

            Text("Coming Soon")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .opacity(0.6)
    }
}

// MARK: - Swatch Colors

private extension AppTheme {
    var swatchColors: [Color] {
        switch self {
        case .desertWarm:
            [DS.Color.warmGlow, DS.Color.desertBronze, DS.Color.desertDusk]
        case .oceanCool:
            [Color("OceanSurface"), Color("OceanMid"), Color("OceanDeep")]
        }
    }
}

#Preview {
    Form {
        Section("Appearance") {
            ThemePickerSection()
        }
    }
}
