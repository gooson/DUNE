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
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: iconName)
                        .foregroundStyle(iconColor)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }

                Text(displayMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var iconName: String {
        insight?.iconName ?? "figure.run.circle.fill"
    }

    private var iconColor: Color {
        guard let category = insight?.category else { return DS.Color.activity }
        switch category {
        case .recovery: return DS.Color.caution
        case .training: return DS.Color.activity
        case .sleep: return DS.Color.sleep
        case .motivation: return DS.Color.positive
        case .recap: return DS.Color.vitals
        case .general: return DS.Color.warmGlow
        }
    }

    private var title: String {
        insight?.title ?? "Today's Coaching"
    }

    private var displayMessage: String {
        insight?.message ?? message ?? ""
    }
}
