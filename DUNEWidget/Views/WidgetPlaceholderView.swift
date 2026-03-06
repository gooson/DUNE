import SwiftUI

struct WidgetPlaceholderView: View {
    let message: LocalizedStringKey
    let iconFont: Font

    var body: some View {
        VStack(spacing: 10) {
            Text("DUNE")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(WidgetDS.Color.textSecondary)

            Image(systemName: "heart.text.clipboard")
                .font(iconFont)
                .foregroundStyle(WidgetDS.Color.textTertiary)

            Text(message)
                .font(.caption)
                .foregroundStyle(WidgetDS.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(WidgetDS.Layout.edgePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
