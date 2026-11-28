import SwiftUI

/// Read-only devices can show a previously stored summary when one is available.
struct CloudSyncWaitingView: View {
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("No health summary on this device")
                .font(DS.Typography.sectionTitle)
            Text("Open Activity to see workouts available on this device.")
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
            if let onRetry {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
}
