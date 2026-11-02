import SwiftUI

/// Fallback screen shown when a notification target no longer exists.
struct NotificationTargetNotFoundView: View {
    let workoutID: String

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 48

    private var palette: ScoreHeroPalette { ScoreHeroPalette(theme: theme, colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    Image(systemName: "exclamationmark.magnifyingglass")
                        .font(.system(size: min(symbolSize, 64), weight: .medium))
                        .foregroundStyle(palette.heroAccent)
                        .accessibilityHidden(true)

                    Text("Exercise not found")
                        .font(.largeTitle.bold())
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("notification-target-not-found-title")

                    Text("The notification target has been deleted or is not synced.")
                        .font(.body)
                        .foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("notification-target-not-found-message")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.xxl)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.xxl))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("notification-target-not-found-hero")

                Text("ID: \(workoutID)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("notification-target-not-found-id")
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(DS.Spacing.lg)
        }
        .accessibilityIdentifier("notification-target-not-found-screen")
        .background { DetailWaveBackground() }
        .englishNavigationTitle("Notification")
    }
}

#Preview {
    NavigationStack {
        NotificationTargetNotFoundView(workoutID: "sample-workout-id")
    }
}
