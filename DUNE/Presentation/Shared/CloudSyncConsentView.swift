import SwiftUI

struct CloudSyncConsentView: View {
    @AppStorage("hasShownCloudSyncConsent") private var hasShownConsent = false
    @AppStorage("isCloudSyncEnabled") private var isCloudSyncEnabled = false
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("iCloud Sync")
                    .font(.title.bold())
                Text("Sync your health records across devices with iCloud. Your data is stored in your private iCloud container.")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    isCloudSyncEnabled = true
                    hasShownConsent = true
                    isPresented = false
                } label: {
                    Text("Enable iCloud Sync")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    isCloudSyncEnabled = false
                    hasShownConsent = true
                    isPresented = false
                } label: {
                    Text("Keep Local Only")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DS.Color.textSecondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background { SheetWaveBackground() }
        .interactiveDismissDisabled()
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

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
