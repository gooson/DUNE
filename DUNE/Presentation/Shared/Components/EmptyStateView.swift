import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(theme.accentColor.opacity(DS.Opacity.strong))
                .padding(.bottom, DS.Spacing.sm)

            Text(title)
                .font(DS.Typography.sectionTitle)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(DS.Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accentColor)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, DS.Spacing.xxxl)
        .background(alignment: .bottom) {
            // Static wave decoration (no animation — empty state shouldn't distract)
            ZStack {
                WaveShape(amplitude: 0.15, frequency: 1.5, phase: 0, verticalOffset: 0.5)
                    .fill(theme.accentColor.opacity(DS.Opacity.subtle))
                WaveShape(amplitude: 0.2, frequency: 2, phase: .pi / 3, verticalOffset: 0.5)
                    .fill(theme.duskColor.opacity(DS.Opacity.subtle))
            }
            .frame(height: 100)
            .clipped()
        }
    }
}
