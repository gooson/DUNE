import SwiftUI

struct WidgetPlaceholderView: View {
    let family: WidgetSurfaceFamily
    let message: LocalizedStringKey
    let iconFont: Font

    var body: some View {
        VStack(spacing: 10) {
            Text("DUNE")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(WidgetDS.Color.textSecondary)
                .accessibilityIdentifier(WidgetSurfaceAccessibility.placeholderBrandID(for: family))

            Image(systemName: "heart.text.clipboard")
                .font(iconFont)
                .foregroundStyle(WidgetDS.Color.textTertiary)
                .accessibilityIdentifier(WidgetSurfaceAccessibility.placeholderIconID(for: family))

            Text(message)
                .font(.caption)
                .foregroundStyle(WidgetDS.Color.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(WidgetSurfaceAccessibility.placeholderMessageID(for: family))
        }
        .padding(WidgetDS.Layout.edgePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(WidgetSurfaceAccessibility.placeholderLaneID(for: family))
    }
}
