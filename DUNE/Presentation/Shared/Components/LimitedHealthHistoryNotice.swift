import SwiftUI

/// Explains gaps that can be caused by a confirmed time-limited HealthKit grant.
struct LimitedHealthHistoryNotice: View {
    var body: some View {
        Label(
            "Earlier health data is outside this app's access. Trends use only available data.",
            systemImage: "lock.shield"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityIdentifier("limited-health-history-notice")
    }
}

#Preview {
    LimitedHealthHistoryNotice()
}
