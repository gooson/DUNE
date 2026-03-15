import SwiftUI

/// Shown on Mac (mirrored read-only mode) while waiting for iCloud data to arrive.
struct CloudSyncWaitingView: View {
    @Environment(\.appTheme) private var theme

    var onRetry: (() -> Void)?

    @State private var showExtendedHelp = false

    private static let extendedHelpDelay: Duration = .seconds(30)

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(theme.accentColor)
                .padding(.bottom, DS.Spacing.sm)

            Text("Syncing with iCloud…")
                .font(DS.Typography.sectionTitle)

            if showExtendedHelp {
                VStack(spacing: DS.Spacing.md) {
                    Text("Taking longer than expected. Make sure iCloud sync is enabled on your iPhone and the DUNE app has been opened recently.")
                        .font(.subheadline)
                        .foregroundStyle(DS.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)

                    if let onRetry {
                        Button(action: onRetry) {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text("Waiting for health data from your iPhone. This may take a moment.")
                    .font(.subheadline)
                    .foregroundStyle(DS.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .animation(.easeInOut(duration: 0.3), value: showExtendedHelp)
        .task {
            do {
                try await Task.sleep(for: Self.extendedHelpDelay)
                showExtendedHelp = true
            } catch {}
        }
    }
}
