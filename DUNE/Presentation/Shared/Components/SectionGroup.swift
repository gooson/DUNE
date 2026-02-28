import SwiftUI

/// Groups content under a labeled section with a rounded material background.
/// Shared between Activity and Wellness tabs.
struct SectionGroup<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    var infoAction: (() -> Void)? = nil
    var fillHeight: Bool = false
    @ViewBuilder let content: () -> Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var cornerRadius: CGFloat { sizeClass == .regular ? DS.Radius.lg : DS.Radius.md }
    private var outerPadding: CGFloat { sizeClass == .regular ? DS.Spacing.xl : DS.Spacing.lg }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack(spacing: DS.Spacing.xs) {
                // Desert accent bar
                RoundedRectangle(cornerRadius: 1)
                    .fill(DS.Gradient.sectionAccent)
                    .frame(width: 2, height: 14)

                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Color.textSecondary)

                if let infoAction {
                    Spacer()

                    Button(action: infoAction) {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(DS.Color.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xs)

            // Card content
            content()
        }
        .padding(outerPadding)
        .frame(maxHeight: fillHeight ? .infinity : nil, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.thinMaterial)
        }
    }
}
