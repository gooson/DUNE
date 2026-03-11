import SwiftUI

/// Shown on Mac (mirrored read-only mode) while waiting for iCloud data to arrive.
struct CloudSyncWaitingView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.accentColor)
                .padding(.bottom, DS.Spacing.sm)

            Text("Syncing with iCloud…")
                .font(DS.Typography.sectionTitle)

            Text("Waiting for health data from your iPhone. This may take a moment.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
}
