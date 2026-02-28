import SwiftUI

/// Theme selection UI. Currently shows Desert Warm as the only available theme
/// with placeholders for future themes. Actual theme switching is a separate task.
struct ThemePickerSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            themeRow(
                name: "Desert Warm",
                colors: [DS.Color.warmGlow, DS.Color.desertBronze, DS.Color.desertDusk],
                isSelected: true,
                isAvailable: true
            )

            themeRow(
                name: "Ocean Cool",
                colors: [.cyan, .blue, .indigo],
                isSelected: false,
                isAvailable: false
            )

            themeRow(
                name: "Forest Green",
                colors: [.green, .mint, .teal],
                isSelected: false,
                isAvailable: false
            )
        }
    }

    private func themeRow(
        name: String,
        colors: [Color],
        isSelected: Bool,
        isAvailable: Bool
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Color swatches
            HStack(spacing: DS.Spacing.xs) {
                ForEach(colors.indices, id: \.self) { index in
                    Circle()
                        .fill(colors[index])
                        .frame(width: 20, height: 20)
                }
            }

            Text(name)
                .foregroundStyle(isAvailable ? .primary : .secondary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(DS.Color.warmGlow)
                    .fontWeight(.semibold)
            } else if !isAvailable {
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .opacity(isAvailable ? 1.0 : 0.6)
    }
}

#Preview {
    Form {
        Section("Appearance") {
            ThemePickerSection()
        }
    }
}
