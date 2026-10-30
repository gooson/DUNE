import SwiftUI

struct CloudSyncConsentView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hasShownCloudSyncConsent") private var hasShownConsent = false
    @AppStorage(CloudSyncPreferenceStore.storageKey) private var isCloudSyncEnabled = false
    @Binding var isPresented: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var heroSymbolSize: CGFloat = 48

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }
    private var infoAccent: Color {
        colorScheme == .light ? palette.border : theme.accentColor
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                hero

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Text("Before you choose")
                        .font(.headline)
                        .padding(.horizontal, 4)

                    InfoRow(
                        icon: "lock.shield",
                        title: "Private storage",
                        description: "Records are kept in your private iCloud container.",
                        accent: infoAccent
                    )
                    InfoRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Across devices",
                        description: "Body composition and exercise records sync across your Apple devices.",
                        accent: infoAccent
                    )
                    InfoRow(
                        icon: "externaldrive",
                        title: "Use without iCloud",
                        description: "Choose local storage to keep records on this device.",
                        accent: infoAccent
                    )
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.top, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .accessibilityIdentifier("cloud-sync-consent-view")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Spacing.md) {
                Button {
                    updateCloudSyncPreference(true)
                } label: {
                    Text("Turn On iCloud Sync")
                        .font(.headline)
                        .foregroundStyle(theme.prominentButtonForegroundColor(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.lg)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("cloud-sync-consent-enable-button")

                Button {
                    updateCloudSyncPreference(false)
                } label: {
                    Text("Keep on This Device")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Color.textSecondary)
                .accessibilityIdentifier("cloud-sync-consent-local-button")
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
            .background(DS.Color.cardBackground)
        }
        .background { SheetWaveBackground() }
        .interactiveDismissDisabled()
        .presentationDetents([.large])
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: heroSymbolSize, weight: .medium))
                .foregroundStyle(palette.heroAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)

            Text("DATA & PRIVACY")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(palette.heroAccent)

            Text("iCloud Sync")
                .font(.largeTitle.bold())
                .foregroundStyle(palette.ink)

            Text("Choose whether to sync your health records across devices.")
                .font(.subheadline)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xxl))
    }

    private func updateCloudSyncPreference(_ isEnabled: Bool) {
        // The forced UI test sheet exercises both decisions without touching iCloud KVS.
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if !(arguments.contains("--uitesting")
             && arguments.contains("--seed-mock")
             && TestDataSeeder.shouldForceCloudSyncConsent(arguments: arguments)) {
            CloudSyncPreferenceStore.setEnabled(isEnabled)
        }
        #else
        CloudSyncPreferenceStore.setEnabled(isEnabled)
        #endif
        isCloudSyncEnabled = isEnabled
        hasShownConsent = true
        isPresented = false
    }
}

private struct InfoRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let accent: Color
    @ScaledMetric(relativeTo: .title3) private var badgeSize: CGFloat = 44
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let usesVerticalLayout = dynamicTypeSize.isAccessibilitySize
        let layout = usesVerticalLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DS.Spacing.lg))
        let resolvedBadgeSize = usesVerticalLayout ? min(badgeSize, 64) : badgeSize

        layout {
            Image(systemName: icon)
                .font(usesVerticalLayout ? .system(size: 32) : .title3)
                .foregroundStyle(accent)
                .frame(width: resolvedBadgeSize, height: resolvedBadgeSize)
                .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !usesVerticalLayout {
                Spacer(minLength: 0)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Color.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
}
