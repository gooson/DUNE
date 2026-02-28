import SwiftUI

/// Coaching card for the Today tab.
/// Displays the focus insight from CoachingEngine with category-aware styling.
struct TodayCoachingCard: View {
    let insight: CoachingInsight?
    let message: String?

    init(insight: CoachingInsight) {
        self.insight = insight
        self.message = nil
    }

    init(message: String) {
        self.insight = nil
        self.message = message
    }

    var body: some View {
        InlineCard {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    Text(displayMessage)
                        .font(.caption)
                        .foregroundStyle(DS.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var iconName: String {
        insight?.iconName ?? "figure.run.circle.fill"
    }

    private var iconColor: Color {
        insight?.category.iconColor ?? DS.Color.activity
    }

    private var title: String {
        insight?.title ?? "Today's Coaching"
    }

    private var displayMessage: String {
        insight?.message ?? message ?? ""
    }
}
