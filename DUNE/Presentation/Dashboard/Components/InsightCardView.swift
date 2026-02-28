import SwiftUI

/// Generic insight card for the Today tab.
/// Displays coaching insights with category-aware icon color and optional dismiss.
struct InsightCardView: View {
    let data: InsightCardData
    let onDismiss: (() -> Void)?

    init(data: InsightCardData, onDismiss: (() -> Void)? = nil) {
        self.data = data
        self.onDismiss = onDismiss
    }

    var body: some View {
        InlineCard {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: data.iconName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(data.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Text(data.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }

                Spacer(minLength: 0)

                if onDismiss != nil {
                    Button {
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var iconColor: Color {
        data.category.iconColor
    }
}
