import SwiftUI

struct WidgetPlaceholderView: View {
    let message: LocalizedStringKey
    let iconFont: Font

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.clipboard")
                .font(iconFont)
                .foregroundStyle(WidgetDS.Color.textTertiary)
            Text(message)
                .font(.caption)
                .foregroundStyle(WidgetDS.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
