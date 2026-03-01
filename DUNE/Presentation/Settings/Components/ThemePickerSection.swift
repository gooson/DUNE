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
        switch self {
        case .desertWarm:
            [DS.Color.warmGlow, DS.Color.desertBronze, DS.Color.desertDusk]
        case .oceanCool:
            [Color("OceanSurface"), Color("OceanMid"), Color("OceanDeep")]
        case .forestGreen:
            [Color("ForestMid"), Color("ForestDeep"), Color("ForestAccent")]
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
