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
        DashboardSupportCard {
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
                        .foregroundStyle(DS.Color.textSecondary)
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
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Dismiss"))
                    .accessibilityIdentifier("dashboard-insight-dismiss-\(data.id)")
                }
            }
        }
        .accessibilityIdentifier("dashboard-insight-\(data.id)")
    }

    private var iconColor: Color {
        data.category.iconColor
    }
}
