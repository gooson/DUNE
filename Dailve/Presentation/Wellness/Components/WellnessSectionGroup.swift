import SwiftUI

/// Groups vital cards under a labeled section with a rounded material background.
struct WellnessSectionGroup<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var cornerRadius: CGFloat { sizeClass == .regular ? DS.Radius.lg : DS.Radius.md }
    private var outerPadding: CGFloat { sizeClass == .regular ? DS.Spacing.xl : DS.Spacing.lg }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.xs)

            // Card content
            content()
        }
        .padding(outerPadding)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.thinMaterial)
        }
    }
}
