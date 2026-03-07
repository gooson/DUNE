import SwiftUI

/// Fallback screen shown when a notification target no longer exists.
struct NotificationTargetNotFoundView: View {
    let workoutID: String

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Exercise not found")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("The notification target has been deleted or is not synced.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("ID: \(workoutID)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Notification")
    }
}

#Preview {
    NavigationStack {
        NotificationTargetNotFoundView(workoutID: "sample-workout-id")
    }
}
