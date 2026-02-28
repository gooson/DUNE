import SwiftUI

/// Shows contextual interpretation and activity guidance based on condition score status.
struct ConditionInsightSection: View {
    let status: ConditionScore.Status

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass == .regular }

    var body: some View {
        VStack(alignment: .leading, spacing: isRegular ? DS.Spacing.md : DS.Spacing.sm) {
            Text("Today's Insight")
                .font(isRegular ? .headline : .subheadline)
                .fontWeight(.semibold)

            InlineCard {
                HStack(alignment: .top, spacing: isRegular ? DS.Spacing.lg : DS.Spacing.md) {
                    Image(systemName: status.iconName)
                        .font(isRegular ? .title : .title2)
                        .foregroundStyle(status.color)
                        .frame(width: isRegular ? 36 : 32)

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(interpretation)
                            .font(isRegular ? .body : .subheadline)
                            .fontWeight(.medium)

                        Text(guidance)
                            .font(isRegular ? .subheadline : .caption)
                            .foregroundStyle(DS.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.label), \(interpretation), \(guidance)")
    }

    // MARK: - Content

    private var interpretation: String {
        switch status {
        case .excellent: String(localized: "You're in peak condition")
        case .good:      String(localized: "Your condition is good")
        case .fair:      String(localized: "You're at your usual level")
        case .tired:     String(localized: "Fatigue has been building up")
        case .warning:   String(localized: "Recovery is needed")
        }
    }

    private var guidance: String {
        switch status {
        case .excellent:
            String(localized: "A great day to try high-intensity workouts or challenging goals. Your body is well-recovered, so push yourself a bit more than usual.")
        case .good:
            String(localized: "Good state to maintain your regular workout routine. Keep up the balanced activity to sustain your condition.")
        case .fair:
            String(localized: "Moderate-intensity activities are recommended. Maintaining a regular sleep pattern can help improve your condition.")
        case .tired:
            String(localized: "Light walks or stretching-focused activities are recommended. Focus on recovery with adequate sleep and rest.")
        case .warning:
            String(localized: "Prioritize rest today. Stick to low-intensity activities and focus on improving your sleep quality.")
        }
    }
}
