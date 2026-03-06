import SwiftUI

/// Theme selection UI with functional theme switching.
struct ThemePickerSection: View {
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shanksPulse: Bool = false
    @State private var shanksPulseTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(AppTheme.allCases, id: \.self) { appTheme in
                themeRow(appTheme)
            }
        }
        .onChange(of: selectedTheme) { _, newValue in
            guard newValue == .shanksRed else { return }
            triggerShanksPulse()
        }
        .onDisappear {
            shanksPulseTask?.cancel()
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

                if appTheme == .shanksRed {
                    ShanksPirateFlagMark()
                        .frame(width: 18, height: 18)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(appTheme.shanksDeepColor.opacity(0.44))
                        )
                        .overlay(
                            Capsule()
                                .stroke(appTheme.bronzeColor.opacity(0.42), lineWidth: 1)
                        )
                        .scaleEffect(
                            selectedTheme == .shanksRed && shanksPulse ? 1.14 : 1.0
                        )
                        .animation(
                            reduceMotion
                            ? .none
                            : .spring(response: 0.30, dampingFraction: 0.57),
                            value: shanksPulse
                        )
                }

                if appTheme == .hanok {
                    HanokRoofTileSealShape()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    appTheme.sandColor.opacity(0.88),
                                    appTheme.scoreExcellent.opacity(0.56),
                                    appTheme.hanokDeepColor.opacity(0.78),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 18, height: 18)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Circle()
                                .fill(appTheme.cardBackground.opacity(0.72))
                        )
                        .overlay(
                            Circle()
                                .stroke(appTheme.hanokMidColor.opacity(0.34), lineWidth: 1)
                        )
                }

                if selectedTheme == appTheme {
                    Image(systemName: "checkmark")
                        .foregroundStyle(appTheme.accentColor)
                        .fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func triggerShanksPulse() {
        guard !reduceMotion else { return }

        shanksPulseTask?.cancel()
        shanksPulse = true
        shanksPulseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 260_000_000)
            shanksPulse = false
        }
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
