import SwiftUI

/// Fallback screen shown when a notification target no longer exists.
struct NotificationTargetNotFoundView: View {
    let workoutID: String

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("해당 운동을 찾을 수 없습니다")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("알림 대상이 삭제되었거나 동기화되지 않았습니다.")
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
