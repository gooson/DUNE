import SwiftUI

struct AppIconPickerView: View {
    @AppStorage(AppIconStyle.storageKey) private var selectedStyle: AppIconStyle = .defaultStyle
    @AppStorage(AppTheme.storageKey) private var selectedTheme: AppTheme = .desertWarm
    @State private var iconService = AppIconService.shared

    private var configuration: AppIconConfiguration {
        AppIconConfiguration(style: selectedStyle, theme: selectedTheme)
    }

    var body: some View {
        Form {
            Section {
                ForEach(AppIconStyle.allCases, id: \.self) { style in
                    Button {
                        selectedStyle = style
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(style.previewAssetName(for: selectedTheme))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .accessibilityHidden(true)
                            Text(style.displayName)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: DS.Spacing.sm)
                            Image(systemName: selectedStyle == style ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedStyle == style ? selectedTheme.accentColor : .secondary)
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, DS.Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(style.displayName)
                    .accessibilityValue(status(for: style))
                    .accessibilityAddTraits(selectedStyle == style ? .isSelected : [])
                    .accessibilityIdentifier("settings-app-icon-\(style.rawValue)")
                }
            } footer: {
                Text("Colors follow the selected theme.")
            }

            Section("Launch Screen") {
                AppLaunchBrandView(style: selectedStyle, theme: selectedTheme)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    .listRowInsets(EdgeInsets())
            }
            Section {
                LabeledContent("Theme", value: selectedTheme.displayName)
                Text(selectedTheme.appIconPaletteName)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings-app-icon-palette")
            } footer: {
                Text("The app icon and launch screen use the same design.")
            }
            if let error = iconService.lastError {
                Section {
                    Text(error).foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task { await iconService.synchronize(configuration) }
                    }
                    .accessibilityIdentifier("settings-app-icon-retry")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { DetailWaveBackground() }
        .englishNavigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: configuration) {
            await iconService.synchronize(configuration)
        }
    }

    private func status(for style: AppIconStyle) -> String {
        guard selectedStyle == style else { return "" }
        if let error = iconService.lastError { return error }
        if iconService.appliedConfiguration == configuration {
            return String(localized: "App icon updated")
        }
        return String(localized: "Updating app icon...")
    }
}

#Preview {
    NavigationStack { AppIconPickerView() }
}
