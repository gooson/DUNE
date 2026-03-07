import SwiftUI

struct CloudSyncConsentView: View {
    @AppStorage("hasShownCloudSyncConsent") private var hasShownConsent = false
    @AppStorage(CloudSyncPreferenceStore.storageKey) private var isCloudSyncEnabled = false
    @Binding var isPresented: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .padding(.top, 32)

                VStack(spacing: 8) {
                    Text("iCloud Sync")
                        .font(.title.bold())
                    Text("Sync your health records across devices with iCloud. Your data is stored in your private iCloud container.")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    InfoRow(
                        icon: "lock.shield",
                        title: "Private & Encrypted",
                        description: "Data is stored in your personal iCloud and encrypted end-to-end."
                    )
                    InfoRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Seamless Sync",
                        description: "Body composition and exercise records sync across your Apple devices."
                    )
                    InfoRow(
                        icon: "externaldrive",
                        title: "Local Option",
                        description: "You can always use the app without iCloud. Data stays on this device."
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Button {
                    updateCloudSyncPreference(true)
                } label: {
                    Text("Enable iCloud Sync")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .accessibilityIdentifier("cloud-sync-consent-enable-button")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    updateCloudSyncPreference(false)
                } label: {
                    Text("Keep Local Only")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("cloud-sync-consent-local-button")
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .background(DS.Color.cardBackground.opacity(0.94))
        }
        .background { SheetWaveBackground() }
        .interactiveDismissDisabled()
        .presentationDetents([.large])
        .accessibilityIdentifier("cloud-sync-consent-view")
    }

    private func updateCloudSyncPreference(_ isEnabled: Bool) {
        CloudSyncPreferenceStore.setEnabled(isEnabled)
        isCloudSyncEnabled = isEnabled
        hasShownConsent = true
        isPresented = false
    }
}

private struct InfoRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(DS.Color.textSecondary)
            }

            Spacer()
        }
    }
}
